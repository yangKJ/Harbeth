//
//  Device.swift
//  Harbeth
//
//  Created by Condy on 2021/8/8.
//

import Foundation
import MetalKit

/// Global public information
public final class Device: Cacheable {
    
    /// Device information to create other objects
    /// MTLDevice creation is expensive, time-consuming, and can be used forever, so you only need to create it once
    let device: MTLDevice
    /// Single command queue
    let commandQueue: MTLCommandQueue
    /// Metal file in your local project
    let defaultLibrary: MTLLibrary?
    /// Metal file in ``Harbeth Framework``
    let harbethLibrary: MTLLibrary?
    /// Load the texture tool
    lazy var textureLoader: MTKTextureLoader = MTKTextureLoader(device: device)
    /// Transform using color space
    lazy var colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    /// We are likely to encounter images with wider colour than sRGB
    lazy var workingColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
    
    /// Cache pipe state
    private var pipelines = [C7KernelFunction: MTLComputePipelineState]()
    /// Lock for thread safety
    private let pipelineLock = NSLock()
    
    /// Memory limit for texture processing in MB
    private var _memoryLimitMB: Int = 512
    
    /// Render operation queue for managing concurrent tasks with QoS
    private let _renderOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.harbeth.render.operation"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    
    /// Command buffer pool for reusing command buffers
    private var _commandBufferPool: CommandBufferPool
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create Metal Device")
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = commandQueue
        
        self.defaultLibrary = try? device.makeDefaultLibrary(bundle: Bundle.main)
        
        self.harbethLibrary = Device.makeFrameworkLibrary(device, for: "Harbeth")

        self._commandBufferPool = CommandBufferPool(maxSize: 4, commandQueue: commandQueue)
    }
    
    deinit {
        print("Device is deinit.")
    }
}

extension Device {
    private static var fallbackLibraries: [String: MTLLibrary] = [:]
    private static let fallbackLibraryLock = NSLock()

    private static var existingSharedDevice: Device? {
        guard Shared.shared.hasDevice else { return nil }
        return Shared.shared.device
    }
    
    public static func metalCapabilityReport(_ capability: C7MetalCapability, on device: MTLDevice? = nil) -> C7MetalCapabilityReport {
        if capability == .customAdvancedEncoder {
            return C7MetalCapabilityReport(
                capability: capability,
                status: .requiresConcreteImplementationCheck,
                minimumPlatform: "Implementation-defined",
                reason: "Higher packages must provide their own availability and device checks."
            )
        }

        let resolvedDevice: MTLDevice? = {
            if let device {
                return device
            }
            if let existingDevice = existingSharedDevice {
                return existingDevice.device
            }
            return MTLCreateSystemDefaultDevice()
        }()

        guard let device = resolvedDevice else {
            return C7MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "Metal device required",
                reason: "No available MTLDevice."
            )
        }
        
        #if os(watchOS)
        return C7MetalCapabilityReport(
            capability: capability,
            status: .unsupported,
            minimumPlatform: "Unavailable on watchOS baseline",
            reason: "Advanced Metal feature probing is not exposed for Harbeth watchOS baseline."
        )
        #else
        switch capability {
        case .customAdvancedEncoder:
            return C7MetalCapabilityReport(
                capability: capability,
                status: .requiresConcreteImplementationCheck,
                minimumPlatform: "Implementation-defined",
                reason: "Higher packages must provide their own availability and device checks."
            )
        case .meshShaders:
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) {
                return C7MetalCapabilityReport(
                    capability: capability,
                    status: .requiresConcreteImplementationCheck,
                    minimumPlatform: "iOS 16 / macOS 13 / tvOS 16",
                    reason: "Object/mesh shader APIs are available; concrete pipeline creation must still be checked by the implementation."
                )
            }
            return C7MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 16 / macOS 13 / tvOS 16",
                reason: "Object/mesh shader APIs are newer than the current runtime."
            )
        case .metalFX:
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) {
                return C7MetalCapabilityReport(
                    capability: capability,
                    status: .requiresConcreteImplementationCheck,
                    minimumPlatform: "iOS 16 / macOS 13",
                    reason: "MetalFX belongs to the MetalFX framework; higher packages must call framework-specific support checks."
                )
            }
            return C7MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 16 / macOS 13",
                reason: "MetalFX is newer than the current runtime."
            )
        case .metalIO:
            #if os(iOS) || os(macOS)
            if #available(macOS 13.0, iOS 16.0, *) {
                return C7MetalCapabilityReport(
                    capability: capability,
                    status: .requiresConcreteImplementationCheck,
                    minimumPlatform: "iOS 16 / macOS 13",
                    reason: "Metal IO APIs are available; concrete streaming strategy must be checked by the implementation."
                )
            }
            #endif
            return C7MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 16 / macOS 13",
                reason: "Metal IO is not available for this platform or runtime."
            )
        case .renderDynamicLibraries:
            if #available(macOS 12.0, iOS 15.0, tvOS 16.0, *) {
                return C7MetalCapabilityReport(
                    capability: capability,
                    status: device.supportsRenderDynamicLibraries ? .supported : .unsupported,
                    minimumPlatform: "iOS 15 / macOS 12 / tvOS 16",
                    reason: device.supportsRenderDynamicLibraries ? "Device reports render dynamic library support." : "Device does not support render dynamic libraries."
                )
            }
            return C7MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 15 / macOS 12 / tvOS 16",
                reason: "Render dynamic libraries are newer than the current runtime."
            )
        case .renderFunctionPointers:
            if #available(macOS 12.0, iOS 15.0, tvOS 16.0, *) {
                return C7MetalCapabilityReport(
                    capability: capability,
                    status: device.supportsFunctionPointersFromRender ? .supported : .unsupported,
                    minimumPlatform: "iOS 15 / macOS 12 / tvOS 16",
                    reason: device.supportsFunctionPointersFromRender ? "Device reports render function pointer support." : "Device does not support render function pointers."
                )
            }
            return C7MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 15 / macOS 12 / tvOS 16",
                reason: "Render function pointers are newer than the current runtime."
            )
        case .rayTracing:
            if #available(macOS 11.0, iOS 14.0, tvOS 16.0, *) {
                return C7MetalCapabilityReport(
                    capability: capability,
                    status: device.supportsRaytracing ? .supported : .unsupported,
                    minimumPlatform: "iOS 14 / macOS 11 / tvOS 16",
                    reason: device.supportsRaytracing ? "Device reports ray tracing support." : "Device does not support ray tracing."
                )
            }
            return C7MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 14 / macOS 11 / tvOS 16",
                reason: "Ray tracing APIs are newer than the current runtime."
            )
        case .sparseTextures:
            if #available(macOS 11.0, iOS 13.0, tvOS 16.0, *) {
                let isSupported = device.sparseTileSizeInBytes > 0
                return C7MetalCapabilityReport(
                    capability: capability,
                    status: isSupported ? .supported : .unsupported,
                    minimumPlatform: "iOS 13 / macOS 11 / tvOS 16",
                    reason: isSupported ? "Device reports sparse texture tile size." : "Device does not report sparse texture support."
                )
            }
            return C7MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 13 / macOS 11 / tvOS 16",
                reason: "Sparse texture APIs are newer than the current runtime."
            )
        }
        #endif
    }
    
    /// Get pipeline state for kernel function with thread safety
    public func pipelineState(for kernel: C7KernelFunction) -> MTLComputePipelineState? {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }
        return pipelines[kernel]
    }
    
    /// Set pipeline state for kernel function with thread safety
    public func setPipelineState(_ pipeline: MTLComputePipelineState, for kernel: C7KernelFunction) {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }
        pipelines[kernel] = pipeline
    }

    var pipelineCount: Int {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }
        return pipelines.count
    }
    
    /// Get maximum concurrent render tasks
    public var maxConcurrentRenderTasks: Int {
        return _renderOperationQueue.maxConcurrentOperationCount
    }
    
    /// Set maximum concurrent render tasks
    /// - Parameter value: Maximum number of concurrent tasks
    public func setMaxConcurrentRenderTasks(_ value: Int) {
        _renderOperationQueue.maxConcurrentOperationCount = value
    }
    
    public static func makeFrameworkLibrary(_ device: MTLDevice, for resource: String) -> MTLLibrary? {
        #if SWIFT_PACKAGE
        /// Fixed the Swift PM cannot read the `.metal` file.
        /// https://stackoverflow.com/questions/63237395/generating-resource-bundle-accessor-type-bundle-has-no-member-module
        if let library = try? device.makeDefaultLibrary(bundle: Bundle.module) {
            return library
        }
        if let pathURL = Bundle.module.url(forResource: "default", withExtension: "metallib") {
            var path: String
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                path = pathURL.path()
            } else {
                path = pathURL.path
            }
            if let library = try? device.makeLibrary(filepath: path) {
                return library
            }
        }
        #endif

        let candidateBundles: [Bundle] = {
            var bundles: [Bundle] = [Bundle(for: Device.self), Bundle.main]
            bundles.append(contentsOf: Bundle.allFrameworks)
            bundles.append(contentsOf: Bundle.allBundles)
            return Array(NSOrderedSet(array: bundles)) as? [Bundle] ?? bundles
        }()

        for bundle in candidateBundles {
            if let library = try? device.makeDefaultLibrary(bundle: bundle) {
                return library
            }
            if let libraryFile = bundle.path(forResource: "default", ofType: "metallib") {
                if let library = try? device.makeLibrary(filepath: libraryFile) {
                    return library
                }
                if #available(macOS 10.13, iOS 11.0, *),
                   let url = URL(string: libraryFile),
                   let library = try? device.makeLibrary(URL: url) {
                    return library
                }
            }
        }

        let bundle = R.readFrameworkBundle(with: resource)
        if let libraryFile = bundle?.path(forResource: "default", ofType: "metallib") {
            if let library = try? device.makeLibrary(filepath: libraryFile) {
                return library
            }
            if #available(macOS 10.13, iOS 11.0, *),
               let url = URL(string: libraryFile),
               let library = try? device.makeLibrary(URL: url) {
                return library
            }
        }

        return nil
    }
    
    private static func makeSourceLibrary(_ device: MTLDevice, fileURL: URL) -> MTLLibrary? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return try? device.makeLibrary(source: content, options: nil)
    }

    private static func makeSourceFallbackLibrary(_ device: MTLDevice, functionName: String) -> MTLLibrary? {
        fallbackLibraryLock.lock()
        if let cached = fallbackLibraries[functionName] {
            fallbackLibraryLock.unlock()
            return cached
        }
        fallbackLibraryLock.unlock()

        if let library = makeSourceLibraryForFunction(device, functionName: functionName) {
            fallbackLibraryLock.lock()
            fallbackLibraries[functionName] = library
            fallbackLibraryLock.unlock()
            return library
        }
        return nil
    }

    private static func makeSourceLibraryForFunction(_ device: MTLDevice, functionName: String) -> MTLLibrary? {
        for fileURL in candidateMetalFiles() {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                  sourceFile(content, containsFunctionNamed: functionName) else {
                continue
            }
            if let library = makeSourceLibrary(device, fileURL: fileURL),
               library.makeFunction(name: functionName) != nil {
                return library
            }
        }
        return nil
    }

    private static func sourceFile(_ content: String, containsFunctionNamed functionName: String) -> Bool {
        let patterns = [
            "kernel void \(functionName)",
            "vertex ",
            "fragment ",
            "kernel ",
            "visible "
        ]
        if content.contains("kernel void \(functionName)") ||
            content.contains("vertex \(functionName)") ||
            content.contains("fragment \(functionName)") {
            return true
        }
        return content.contains("\(functionName)(") && patterns.contains { content.contains($0) }
    }

    private static func candidateMetalFiles() -> [URL] {
        let fileURL = URL(fileURLWithPath: #filePath)
        let sourcesRoot = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var directories: [URL] = []
        directories.append(sourcesRoot)
        #if SWIFT_PACKAGE
        if let resourceURL = Bundle.module.resourceURL {
            directories.append(resourceURL)
        }
        #endif
        let bundles: [Bundle] = {
            var bundles: [Bundle] = [Bundle(for: Device.self), Bundle.main]
            bundles.append(contentsOf: Bundle.allFrameworks)
            bundles.append(contentsOf: Bundle.allBundles)
            return Array(NSOrderedSet(array: bundles)) as? [Bundle] ?? bundles
        }()
        directories.append(contentsOf: bundles.compactMap(\.resourceURL))

        var seen = Set<String>()
        var files: [URL] = []
        for directory in directories {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "metal" {
                let path = fileURL.path
                guard seen.insert(path).inserted else { continue }
                files.append(fileURL)
            }
        }
        return files
    }
    
    public static func readMTLFunction(_ name: String) throws -> MTLFunction {
        /// Read external libraries
        if let device = existingSharedDevice {
            for library in device.externalLibraries() {
                if let function = library.makeFunction(name: name) {
                    return function
                }
            }
        }
        // And then read the project
        if let libray = existingSharedDevice?.defaultLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        // Last read from ``Harbeth Framework``
        if let libray = existingSharedDevice?.harbethLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        if let metalDevice = existingSharedDevice?.device ?? MTLCreateSystemDefaultDevice(),
           let fallbackLibrary = makeSourceFallbackLibrary(metalDevice, functionName: name),
           let function = fallbackLibrary.makeFunction(name: name) {
            return function
        }
        #if DEBUG
        fatalError(metalFunctionLookupFailureDescription(name))
        #else
        throw HarbethError.readFunction(name)
        #endif
    }

    public static func metalFunctionLookupFailureDescription(_ name: String) -> String {
        let sharedDevice = existingSharedDevice
        var errorMessage = "Could not find Metal function '\(name)' in any library.\nCandidate sources:\n"
        errorMessage += "- Default Library: \(sharedDevice?.defaultLibrary != nil ? "Available" : "Not available")\n"
        errorMessage += "- Harbeth Library: \(sharedDevice?.harbethLibrary != nil ? "Available" : "Not available")\n"
        errorMessage += "- External Registry:\n\(Device.externalLibraryRegistryDebugDescription())"
        return errorMessage
    }
}

extension Device {
    
    public enum GPUArchitecture {
        case appleSilicon, intel, unknown
    }
    
    public static func detectGPUArchitecture() -> GPUArchitecture {
        let device = Device.device()
        if device.name.contains("Apple") {
            return .appleSilicon
        } else if device.name.contains("Intel") {
            return .intel
        } else {
            return .unknown
        }
    }
    
    public static func device() -> MTLDevice {
        return Shared.shared.device!.device
    }
    
    public static func colorSpace() -> CGColorSpace {
        // Unitive the color space, otherwise it will crash.
        return Shared.shared.device?.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    }
    
    public static func bitmapInfo() -> UInt32 {
        // You can't get `CGImage.bitmapInfo` here, otherwise the heic and heif formats will turn blue.
        // Fixed draw bitmap after applying filter image color rgba => bgra.
        // See：https://github.com/yangKJ/Harbeth/issues/12
        return CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    }
    
    public static func commandQueue() -> MTLCommandQueue {
        return Shared.shared.device!.commandQueue
    }
    
    public static func sharedTextureCache() -> CVMetalTextureCache? {
        return Shared.shared.device?.textureCache
    }
    
    public static var renderOperationQueue: OperationQueue {
        return Shared.shared.device!._renderOperationQueue
    }
    
    public static var memoryLimitMB: Int {
        return Shared.shared.device!._memoryLimitMB
    }
    
    public static func setMemoryLimitMB(_ value: Int) {
        Shared.shared.device!._memoryLimitMB = value
    }
    
    /// Get a command buffer from the pool
    public static func getCommandBuffer() -> MTLCommandBuffer? {
        return Shared.shared.device?._commandBufferPool.get()
    }
    
    /// Return a command buffer to the pool
    public static func returnCommandBuffer(_ buffer: MTLCommandBuffer) {
        Shared.shared.device!._commandBufferPool.put(buffer)
    }
    
    
    public static func makeTexture2DMaxSize(width: Int, height: Int) -> (width: Int, height: Int) {
        func getMaxTextureDimensions() -> (width: Int, height: Int) {
            #if targetEnvironment(macCatalyst)
            if Device.device().supportsFamily(.apple3) {
                return (131072, 65536)
            } else {
                return (8192, 8192)
            }
            #elseif os(macOS)
            return (131072, 65536)
            #else
            if #available(iOS 13.0, *) {
                if Device.device().supportsFamily(.apple3) {
                    return (65536, 65536)
                } else {
                    return (16384, 16384)
                }
            } else if #available(iOS 11.0, *)  {
                if Device.device().supportsFeatureSet(.iOS_GPUFamily3_v3) {
                    return (16384, 16384)
                } else {
                    return (8192, 8192)
                }
            } else {
                return (8192, 8192)
            }
            #endif
        }
        guard width > 0, height > 0 else {
            return (0, 0)
        }
        let (maxWidth, maxHeight) = getMaxTextureDimensions()
        let aspectRatio = Float(width) / Float(height)
        if aspectRatio > 1 {
            let resultWidth = min(width, maxWidth)
            let resultHeight = Float(resultWidth) / aspectRatio
            return (width: resultWidth, height: min(Int(resultHeight.rounded()), maxHeight))
        } else {
            let resultHeight = min(height, maxHeight)
            let resultWidth = Float(resultHeight) * aspectRatio
            return (width: min(Int(resultWidth.rounded()), maxWidth), height: resultHeight)
        }
    }
}

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
    /// CIContexts
    lazy var contexts = [CGColorSpace: CIContext]()
    
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
        
        if defaultLibrary == nil && harbethLibrary == nil {
            HarbethError.failed("Could not load library")
        }
        
        self._commandBufferPool = CommandBufferPool(maxSize: 4, commandQueue: commandQueue)
    }
    
    deinit {
        print("Device is deinit.")
    }
}

extension Device {
    
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
        
        /// Fixed the read failure of imported local resources was rectified.
        if let library = try? device.makeDefaultLibrary(bundle: Bundle(for: Device.self)) {
            return library
        }
        
        let bundle = R.readFrameworkBundle(with: resource)
        /// Fixed libraryFile is nil. podspec file `s.static_framework = false`
        /// https://github.com/CocoaPods/CocoaPods/issues/7967
        guard let libraryFile = bundle?.path(forResource: "default", ofType: "metallib") else {
            return nil
        }
        
        /// Compatible with the Bundle address used by CocoaPods to import framework.
        if let library = try? device.makeLibrary(filepath: libraryFile) {
            return library
        }
        
        if #available(macOS 10.13, iOS 11.0, *) {
            if let url = URL(string: libraryFile), let library = try? device.makeLibrary(URL: url) {
                return library
            }
        }
        
        return nil
    }
    
    public static func readMTLFunction(_ name: String) throws -> MTLFunction {
        /// Read external libraries
        if let device = Shared.shared.device {
            for library in device.externalLibraries() {
                if let function = library.makeFunction(name: name) {
                    return function
                }
            }
        }
        // And then read the project
        if let libray = Shared.shared.device?.defaultLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        // Last read from ``Harbeth Framework``
        if let libray = Shared.shared.device?.harbethLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        #if DEBUG
        var errorMessage = "Could not find Metal function '\(name)' in any library.\nAvailable libraries:\n"
        errorMessage += "- Default Library: \(Shared.shared.device?.defaultLibrary != nil ? "Available" : "Not available")\n"
        errorMessage += "- Harbeth Library: \(Shared.shared.device?.harbethLibrary != nil ? "Available" : "Not available")\n"
        errorMessage += "- External Library Registry: \(Shared.shared.device?.externalLibraries().count ?? 0) libraries registered"
        fatalError(errorMessage)
        #else
        throw HarbethError.readFunction(name)
        #endif
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
    
    public static func context() -> CIContext {
        Device.context(colorSpace: Device.colorSpace())
    }
    
    public static func context(cgImage: CGImage) -> CIContext {
        let colorSpace = cgImage.colorSpace ?? Device.colorSpace()
        return Device.context(colorSpace: colorSpace)
    }
    
    public static func context(colorSpace: CGColorSpace) -> CIContext {
        if let context = Shared.shared.device?.contexts[colorSpace] {
            return context
        }
        var options: [CIContextOption : Any] = [
            // Specify the default destination color space for rendering.
            CIContextOption.outputColorSpace: colorSpace,
            // Caching does provide a minor speed boost without ballooning memory use, so let's have it on
            CIContextOption.cacheIntermediates: true,
            // Low GPU priority would make sense for a background operation that isn't performance-critical,
            // but we are interested in disk-to-display performance
            CIContextOption.priorityRequestLow: false,
            // Definitely no CPU rendering, please
            CIContextOption.useSoftwareRenderer: false,
            // This is the Apple recommendation, see cgImage(using:) above
            CIContextOption.workingFormat: CIFormat.RGBAh,
            /// Render produces alpha-premultiplied pixels.
            CIContextOption.outputPremultiplied: true,
        ]
        if #available(iOS 13.0, macOS 10.12, *) {
            // This option is undocumented, possibly only effective on iOS?
            // Sounds more like allowLowPerformance, though, so turn it off
            options[CIContextOption.allowLowPower] = false
        }
        if let workingColorSpace = Shared.shared.device?.workingColorSpace {
            // We are likely to encounter images with wider colour than sRGB
            options[CIContextOption.workingColorSpace] = workingColorSpace
        }
        let context: CIContext
        if #available(iOS 13.0, *, macOS 10.15, *) {
            context = CIContext(mtlCommandQueue: Device.commandQueue(), options: options)
        } else if #available(iOS 9.0, *) {
            context = CIContext(mtlDevice: Device.device(), options: options)
        } else {
            context = CIContext(options: options)
        }
        Shared.shared.device?.contexts[colorSpace] = context
        return context
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

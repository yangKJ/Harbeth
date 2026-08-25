//
//  Device.swift
//  Harbeth
//
//  Created by Condy on 2021/8/8.
//

import Foundation
import MetalKit

/// Process-lifetime Metal resources used by HarbethContext.
final class Device {
    /// Device information to create other objects
    /// MTLDevice creation is expensive, time-consuming, and can be used forever, so you only need to create it once
    let device: MTLDevice
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
    private var identityPipelines = [String: MTLComputePipelineState]()
    private var identityFunctions = [String: MTLFunction]()
    /// Lock for thread safety
    private let pipelineLock = NSLock()
    private let functionLock = NSLock()
    let externalLibraryRegistry = ExternalLibraryProviderRegistry()
    private var fallbackLibraries: [String: MTLLibrary] = [:]
    private var fallbackMisses: Set<String> = []
    private var cachedMetalFiles: [URL]?
    private let fallbackLibraryLock = NSLock()
    private(set) var sourceFallbackScanCount = 0

    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create Metal Device")
        }
        self.device = device
        self.defaultLibrary = try? device.makeDefaultLibrary(bundle: Bundle.main)
        self.harbethLibrary = Device.makeFrameworkLibrary(device, for: "Harbeth")
    }
}

extension Device {
    private static func capabilityMinimumPlatform(_ capability: MetalCapability) -> String {
        switch capability {
        case .heapTexturePool:
            return "iOS 13 / macOS 10.15 / tvOS 13 / Mac Catalyst 13"
        case .meshShaders:
            return "iOS 16 / macOS 13"
        case .metalFX:
            return "iOS 16 / macOS 13"
        case .metalIO:
            return "iOS 16 / macOS 13"
        case .renderDynamicLibraries:
            return "iOS 15 / macOS 12 / tvOS 16"
        case .renderFunctionPointers:
            return "iOS 15 / macOS 12 / tvOS 16"
        case .rayTracing:
            return "iOS 14 / macOS 11 / tvOS 16"
        case .sparseTextures:
            return "iOS 13 / macOS 11 / tvOS 16"
        }
    }

    /// Function names confirmed absent from on-disk `.metal` sources, cached so a missing kernel
    /// is scanned for at most once instead of re-walking the whole bundle on every lookup.
    /// Cached list of `.metal` source files in the bundle. The set is process-stable, so the
    /// expensive recursive enumeration runs at most once even when several kernels miss.
    /// Regression gate: number of times the source-fallback bundle scan actually ran. The
    /// contract is "precompiled libraries are tried first, the scan is only a last resort", so a
    /// kernel present in any library must add 0 here. `SourceFallbackGateTests` asserts this to
    /// stop a future refactor from silently making the fallback eager again.
    static var sourceFallbackScanCount: Int {
        HarbethContext.shared.runtimeDevice.sourceFallbackScanCount
    }

    static func metalCapabilityReport(_ capability: MetalCapability, on device: MTLDevice? = nil) -> MetalCapabilityReport {
        let resolvedDevice = device ?? HarbethContext.shared.runtimeDevice.device
        switch capability {
        case .heapTexturePool:
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, macCatalyst 13.0, *) {
                let isSupported: Bool
                #if targetEnvironment(macCatalyst)
                isSupported = resolvedDevice.supportsFamily(.macCatalyst1)
                #elseif os(macOS)
                isSupported = resolvedDevice.supportsFamily(.mac1)
                #elseif os(iOS) || os(tvOS)
                isSupported = resolvedDevice.supportsFamily(.apple5)
                #else
                isSupported = false
                #endif
                return MetalCapabilityReport(
                    capability: capability,
                    status: isSupported ? .supported : .unsupported,
                    minimumPlatform: capabilityMinimumPlatform(capability),
                    reason: isSupported
                        ? "Device meets Harbeth's heap-backed texture reuse family requirement."
                        : "Device does not meet the heap texture pool family requirement (Apple5 / Mac1 / MacCatalyst1)."
                )
            }
            return MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: capabilityMinimumPlatform(capability),
                reason: "Heap texture pool support is newer than the current runtime."
            )
        case .meshShaders:
            #if os(macOS) || os(iOS)
            if #available(macOS 13.0, iOS 16.0, *) {
                let isSupported: Bool
                #if targetEnvironment(macCatalyst)
                isSupported = resolvedDevice.supportsFamily(.mac2)
                #elseif os(macOS)
                isSupported = resolvedDevice.supportsFamily(.mac2)
                #else
                isSupported = resolvedDevice.supportsFamily(.apple7)
                #endif
                return MetalCapabilityReport(
                    capability: capability,
                    status: isSupported ? .requiresConcreteImplementationCheck : .unsupported,
                    minimumPlatform: capabilityMinimumPlatform(capability),
                    reason: isSupported
                        ? "Device family supports mesh shaders; concrete pipeline creation must still be checked by the implementation."
                        : "Device does not meet Harbeth's Apple7 / Mac2 mesh shader family requirement."
                )
            }
            #endif
            return MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: capabilityMinimumPlatform(capability),
                reason: "Mesh shaders are not available for this platform, runtime or GPU family."
            )
        case .metalFX:
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) {
                return MetalCapabilityReport(
                    capability: capability,
                    status: .requiresConcreteImplementationCheck,
                    minimumPlatform: capabilityMinimumPlatform(capability),
                    reason:
                        "MetalFX belongs to the MetalFX framework; higher packages must call framework-specific support checks."
                )
            }
            return MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: capabilityMinimumPlatform(capability),
                reason: "MetalFX is newer than the current runtime."
            )
        case .metalIO:
            #if os(iOS) || os(macOS)
            if #available(macOS 13.0, iOS 16.0, *) {
                return MetalCapabilityReport(
                    capability: capability,
                    status: .requiresConcreteImplementationCheck,
                    minimumPlatform: capabilityMinimumPlatform(capability),
                    reason: "Metal IO APIs are available; concrete streaming strategy must be checked by the implementation."
                )
            }
            #endif
            return MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: capabilityMinimumPlatform(capability),
                reason: "Metal IO is not available for this platform or runtime."
            )
        case .renderDynamicLibraries:
            if #available(macOS 12.0, iOS 15.0, tvOS 16.0, *) {
                return MetalCapabilityReport(
                    capability: capability,
                    status: resolvedDevice.supportsRenderDynamicLibraries ? .supported : .unsupported,
                    minimumPlatform: "iOS 15 / macOS 12 / tvOS 16",
                    reason: resolvedDevice.supportsRenderDynamicLibraries
                        ? "Device reports render dynamic library support."
                        : "Device does not support render dynamic libraries."
                )
            }
            return MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 15 / macOS 12 / tvOS 16",
                reason: "Render dynamic libraries are newer than the current runtime."
            )
        case .renderFunctionPointers:
            if #available(macOS 12.0, iOS 15.0, tvOS 16.0, *) {
                return MetalCapabilityReport(
                    capability: capability,
                    status: resolvedDevice.supportsFunctionPointersFromRender ? .supported : .unsupported,
                    minimumPlatform: "iOS 15 / macOS 12 / tvOS 16",
                    reason: resolvedDevice.supportsFunctionPointersFromRender
                        ? "Device reports render function pointer support."
                        : "Device does not support render function pointers."
                )
            }
            return MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 15 / macOS 12 / tvOS 16",
                reason: "Render function pointers are newer than the current runtime."
            )
        case .rayTracing:
            if #available(macOS 11.0, iOS 14.0, tvOS 16.0, *) {
                return MetalCapabilityReport(
                    capability: capability,
                    status: resolvedDevice.supportsRaytracing ? .supported : .unsupported,
                    minimumPlatform: "iOS 14 / macOS 11 / tvOS 16",
                    reason: resolvedDevice.supportsRaytracing
                        ? "Device reports ray tracing support." : "Device does not support ray tracing."
                )
            }
            return MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 14 / macOS 11 / tvOS 16",
                reason: "Ray tracing APIs are newer than the current runtime."
            )
        case .sparseTextures:
            if #available(macOS 11.0, iOS 13.0, tvOS 16.0, *) {
                let isSupported = resolvedDevice.sparseTileSizeInBytes > 0
                return MetalCapabilityReport(
                    capability: capability,
                    status: isSupported ? .supported : .unsupported,
                    minimumPlatform: "iOS 13 / macOS 11 / tvOS 16",
                    reason: isSupported
                        ? "Device reports sparse texture tile size." : "Device does not report sparse texture support."
                )
            }
            return MetalCapabilityReport(
                capability: capability,
                status: .unsupported,
                minimumPlatform: "iOS 13 / macOS 11 / tvOS 16",
                reason: "Sparse texture APIs are newer than the current runtime."
            )
        }
    }

    /// Get pipeline state for kernel function with thread safety
    func pipelineState(for kernel: C7KernelFunction) -> MTLComputePipelineState? {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }
        return pipelines[kernel]
    }

    /// Set pipeline state for kernel function with thread safety
    func setPipelineState(_ pipeline: MTLComputePipelineState, for kernel: C7KernelFunction) {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }
        pipelines[kernel] = pipeline
    }

    func pipelineState(for identity: KernelFunctionIdentity) -> MTLComputePipelineState? {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }
        return identityPipelines[identity.fingerprint]
    }

    func setPipelineState(_ pipeline: MTLComputePipelineState, for identity: KernelFunctionIdentity) {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }
        identityPipelines[identity.fingerprint] = pipeline
    }

    func cachedFunction(for identity: KernelFunctionIdentity) -> MTLFunction? {
        functionLock.lock()
        defer { functionLock.unlock() }
        return identityFunctions[identity.fingerprint]
    }

    func setCachedFunction(_ function: MTLFunction, for identity: KernelFunctionIdentity) {
        functionLock.lock()
        defer { functionLock.unlock() }
        identityFunctions[identity.fingerprint] = function
    }

    func removePipelineStates() {
        pipelineLock.lock()
        pipelines.removeAll()
        identityPipelines.removeAll()
        pipelineLock.unlock()
    }

    func removeFunctionCache() {
        functionLock.lock()
        identityFunctions.removeAll()
        functionLock.unlock()
    }

    var pipelineCount: Int {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }
        return pipelines.count + identityPipelines.count
    }

    var functionCacheCount: Int {
        functionLock.lock()
        defer { functionLock.unlock() }
        return identityFunctions.count
    }

    static func makeFrameworkLibrary(_ device: MTLDevice, for resource: String) -> MTLLibrary? {
        #if SWIFT_PACKAGE
        /// Fixed the Swift PM cannot read the `.metal` file.
        /// https://stackoverflow.com/questions/63237395/generating-resource-bundle-accessor-type-bundle-has-no-member-module
        if let library = try? device.makeDefaultLibrary(bundle: Bundle.module) { return library }
        if let pathURL = Bundle.module.url(forResource: "default", withExtension: "metallib") {
            var path: String
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) { path = pathURL.path() } else { path = pathURL.path }
            if let library = try? device.makeLibrary(filepath: path) { return library }
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
                if let library = try? device.makeLibrary(filepath: libraryFile) { return library }
                if #available(macOS 10.13, iOS 11.0, *), let url = URL(string: libraryFile),
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
            if #available(macOS 10.13, iOS 11.0, *), let url = URL(string: libraryFile),
               let library = try? device.makeLibrary(URL: url) {
                return library
            }
        }

        return nil
    }

    private func makeSourceLibrary(_ device: MTLDevice, fileURL: URL) -> MTLLibrary? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return try? device.makeLibrary(source: content, options: nil)
    }

    private func makeSourceFallbackLibrary(_ device: MTLDevice, functionName: String) -> MTLLibrary? {
        fallbackLibraryLock.lock()
        if let cached = fallbackLibraries[functionName] {
            fallbackLibraryLock.unlock()
            return cached
        }
        if fallbackMisses.contains(functionName) {
            fallbackLibraryLock.unlock()
            return nil
        }
        sourceFallbackScanCount += 1
        fallbackLibraryLock.unlock()

        if let library = makeSourceLibraryForFunction(device, functionName: functionName) {
            fallbackLibraryLock.lock()
            fallbackLibraries[functionName] = library
            fallbackLibraryLock.unlock()
            return library
        }
        // Remember the miss so a kernel that genuinely has no on-disk source is not rescanned.
        fallbackLibraryLock.lock()
        fallbackMisses.insert(functionName)
        fallbackLibraryLock.unlock()
        return nil
    }

    private func makeSourceLibraryForFunction(_ device: MTLDevice, functionName: String) -> MTLLibrary? {
        for fileURL in candidateMetalFiles() {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                  Self.sourceFile(content, containsFunctionNamed: functionName) else {
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
        let patterns = ["kernel void \(functionName)", "vertex ", "fragment ", "kernel ", "visible "]
        if content.contains("kernel void \(functionName)")
            || content.contains("vertex \(functionName)")
            || content.contains("fragment \(functionName)") {
            return true
        }
        return content.contains("\(functionName)(") && patterns.contains { content.contains($0) }
    }

    private func candidateMetalFiles() -> [URL] {
        fallbackLibraryLock.lock()
        if let cachedMetalFiles {
            fallbackLibraryLock.unlock()
            return cachedMetalFiles
        }
        fallbackLibraryLock.unlock()

        let fileURL = URL(fileURLWithPath: #filePath)
        let sourcesRoot = fileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        var directories: [URL] = []
        directories.append(sourcesRoot)
        #if SWIFT_PACKAGE
        if let resourceURL = Bundle.module.resourceURL { directories.append(resourceURL) }
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
        fallbackLibraryLock.lock()
        cachedMetalFiles = files
        fallbackLibraryLock.unlock()
        return files
    }

    func readMTLFunction(_ name: String) throws -> MTLFunction {
        /// Read external libraries
        for library in externalLibraries() {
            if let function = library.makeFunction(name: name) {
                return function
            }
        }
        // And then read the project
        if let libray = defaultLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        // Last read from ``Harbeth Framework``
        if let libray = harbethLibrary, let function = libray.makeFunction(name: name) {
            return function
        }
        if let fallbackLibrary = makeSourceFallbackLibrary(device, functionName: name),
           let function = fallbackLibrary.makeFunction(name: name) {
            return function
        }
        throw HarbethError.readFunction(name)
    }

    func readMTLFunction(_ identity: KernelFunctionIdentity) throws -> MTLFunction {
        guard identity.kind != .blit else {
            throw HarbethError.readFunction(identity.primaryName)
        }

        let functionName = identity.primaryName
        let constantValues = identity.makeMetalFunctionConstantValues()
        if identity.functionConstants.isEmpty == false, constantValues == nil {
            throw HarbethError.configurationInvalid(
                "Metal function constants for \(functionName) contain an unsupported value."
            )
        }
        let resolvedDevice = self

        if let cached = resolvedDevice.cachedFunction(for: identity) {
            return cached
        }

        func makeFunction(from library: MTLLibrary) -> MTLFunction? {
            if let constantValues {
                return try? library.makeFunction(name: functionName, constantValues: constantValues)
            }
            return library.makeFunction(name: functionName)
        }

        let candidateLibraries: [MTLLibrary] = {
            switch identity.librarySource {
            case .automatic:
                // Precompiled libraries only. The source fallback — which recursively scans
                // every bundle for `.metal` files and compiles them (hundreds of ms to
                // seconds) — is deferred to a last resort tried AFTER these all miss (see the
                // post-loop fallback below), so a kernel that already lives in the metallib
                // never pays the filesystem walk.
                var libraries = resolvedDevice.externalLibraries()
                if let library = resolvedDevice.defaultLibrary {
                    libraries.append(library)
                }
                if let library = resolvedDevice.harbethLibrary {
                    libraries.append(library)
                }
                return libraries
            case .defaultLibrary:
                return resolvedDevice.defaultLibrary.map { [$0] } ?? []
            case .harbethFramework:
                return resolvedDevice.harbethLibrary.map { [$0] } ?? []
            case .externalProvider(let identifier):
                return resolvedDevice.externalLibraries(matching: identifier)
            case .metallibURL(let path):
                let url: URL
                if let parsedURL = URL(string: path), let scheme = parsedURL.scheme {
                    guard scheme == "file" else { return [] }
                    url = parsedURL
                } else {
                    url = URL(fileURLWithPath: path)
                }
                let library: MTLLibrary?
                if url.isFileURL {
                    library = try? resolvedDevice.device.makeLibrary(URL: url)
                } else {
                    library = nil
                }
                return library.map { [$0] } ?? []
            case .sourceFallback:
                return makeSourceFallbackLibrary(resolvedDevice.device, functionName: functionName).map { [$0] } ?? []
            }
        }()

        for library in candidateLibraries {
            if let function = makeFunction(from: library) {
                resolvedDevice.setCachedFunction(function, for: identity)
                return function
            }
        }

        // Last resort for `.automatic`: only when the function is in NO precompiled library
        // do we pay for the source-fallback bundle scan + compile. This keeps the common
        // path (kernel present in the metallib) free of the recursive filesystem walk that
        // previously ran eagerly on every cold lookup.
        if case .automatic = identity.librarySource,
           let fallbackLibrary = makeSourceFallbackLibrary(resolvedDevice.device, functionName: functionName),
           let function = makeFunction(from: fallbackLibrary) {
            resolvedDevice.setCachedFunction(function, for: identity)
            return function
        }

        HarbethLogger.log(
            .error,
            category: "metal-function",
            code: HarbethError.readFunction(functionName).harbethDiagnosticCode,
            outcome: .failed,
            metadata: ["function": functionName],
            message: metalFunctionLookupFailureDescription(identity)
        )
        throw HarbethError.readFunction(functionName)
    }

    func metalFunctionLookupFailureDescription(_ name: String) -> String {
        let runtimeDevice: Device? = self
        var errorMessage = "Could not find Metal function '\(name)' in any library.\nCandidate sources:\n"
        errorMessage += "- Default Library: \(runtimeDevice?.defaultLibrary != nil ? "Available" : "Not available")\n"
        errorMessage += "- Harbeth Library: \(runtimeDevice?.harbethLibrary != nil ? "Available" : "Not available")\n"
        errorMessage += "- External Registry:\n\(externalLibraryRegistryDebugDescription())"
        return errorMessage
    }

    func metalFunctionLookupFailureDescription(_ identity: KernelFunctionIdentity) -> String {
        var errorMessage = metalFunctionLookupFailureDescription(identity.primaryName)
        errorMessage += "\nRequested identity: \(identity.fingerprint)"
        return errorMessage
    }
}

extension Device {
    private static var compatibilityOwner: Device { HarbethContext.shared.runtimeDevice }

    static func readMTLFunction(_ name: String) throws -> MTLFunction {
        try compatibilityOwner.readMTLFunction(name)
    }

    static func readMTLFunction(_ identity: KernelFunctionIdentity) throws -> MTLFunction {
        try compatibilityOwner.readMTLFunction(identity)
    }

    static func metalFunctionLookupFailureDescription(_ name: String) -> String {
        compatibilityOwner.metalFunctionLookupFailureDescription(name)
    }

    static func metalFunctionLookupFailureDescription(_ identity: KernelFunctionIdentity) -> String {
        compatibilityOwner.metalFunctionLookupFailureDescription(identity)
    }

    func resetLibraryCaches() {
        fallbackLibraryLock.lock()
        fallbackLibraries.removeAll()
        fallbackMisses.removeAll()
        cachedMetalFiles = nil
        sourceFallbackScanCount = 0
        fallbackLibraryLock.unlock()
        removePipelineStates()
        removeFunctionCache()
    }

    enum GPUArchitecture {
        case appleSilicon, intel, unknown
    }

    static func detectGPUArchitecture() -> GPUArchitecture {
        let device = HarbethContext.shared.device
        if device.name.contains("Apple") {
            return .appleSilicon
        } else if device.name.contains("Intel") {
            return .intel
        } else {
            return .unknown
        }
    }

    static func device() -> MTLDevice {
        HarbethContext.shared.device
    }

    static func colorSpace() -> CGColorSpace {
        // Unitive the color space, otherwise it will crash.
        return HarbethContext.shared.colorSpace
    }

    static func bitmapInfo() -> UInt32 {
        // You can't get `CGImage.bitmapInfo` here, otherwise the heic and heif formats will turn blue.
        // Fixed draw bitmap after applying filter image color rgba => bgra.
        // See：https://github.com/yangKJ/Harbeth/issues/12
        return CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    }

    static func makeTexture2DMaxSize(width: Int, height: Int) -> (width: Int, height: Int) {
        func getMaxTextureDimensions() -> (width: Int, height: Int) {
            #if targetEnvironment(macCatalyst)
            if HarbethContext.shared.device.supportsFamily(.apple3) {
                return (131072, 65536)
            } else {
                return (8192, 8192)
            }
            #elseif os(macOS)
            return (131072, 65536)
            #else
            if HarbethContext.shared.device.supportsFamily(.apple3) {
                return (65536, 65536)
            } else {
                return (16384, 16384)
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

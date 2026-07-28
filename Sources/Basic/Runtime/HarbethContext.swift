//
//  HarbethContext.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
@preconcurrency import Metal

#if os(iOS) || os(tvOS)
import UIKit
#endif

public final class HarbethContext: @unchecked Sendable {

    public static var shared: HarbethContext {
        Shared.shared.defaultContext
    }

    private let legacyDevice: Device
    private let renderPipelineLock = NSLock()
    private let samplerLock = NSLock()
    private let imageResolutionLock = NSLock()
    private let renderPlanLock = NSLock()
    private var renderPipelines: [RenderPipelineCacheKey: MTLRenderPipelineState] = [:]
    private var samplerStates: [SamplerCacheKey: MTLSamplerState] = [:]
    private var imageResolutionCache: [String: MTLTexture] = [:]
    private var imageResolutionCacheOrder: [String] = []
    private var imageResolutionCacheByteSizes: [String: Int] = [:]
    private var imageResolutionCacheByteCount = 0
    private let imageResolutionCacheLimit: Int = 64
    private let imageResolutionCacheByteLimit: Int
    private var imageResolutionCacheNamespace: String = "default"
    /// LRU cache for compiled RenderPlan.
    /// Key: `nodeFingerprint|profile.rawValue|derivative.name|samplerDescriptor.fingerprint`
    /// Value: compiled RenderPlan (a large struct, ~10-50 KB)
    /// On hit, the key moves to the tail as most-recently-used.
    private var renderPlanCache: [String: RenderPlan] = [:]
    private var renderPlanCacheOrder: [String] = []
    private let renderPlanCacheLimit: Int = 100

    #if os(iOS) || os(tvOS)
    private var memoryWarningObserver: NSObjectProtocol?
    #elseif os(macOS)
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    #endif

    init(device: Device) {
        self.legacyDevice = device
        let physicalMemory = Int(clamping: ProcessInfo.processInfo.physicalMemory)
        self.imageResolutionCacheByteLimit = min(max(physicalMemory / 50, 32 * 1024 * 1024), 256 * 1024 * 1024)
        #if os(iOS) || os(tvOS)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.purgeMemorySensitiveCaches()
        }
        #elseif os(macOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.critical, .warning])
        source.setEventHandler { [weak self] in self?.purgeMemorySensitiveCaches() }
        source.resume()
        memoryPressureSource = source
        #endif
    }

    deinit {
        #if os(iOS) || os(tvOS)
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
        #elseif os(macOS)
        memoryPressureSource?.cancel()
        #endif
    }

    public var device: MTLDevice {
        legacyDevice.device
    }

    public var commandQueue: MTLCommandQueue {
        legacyDevice.commandQueue
    }

    public var texturePool: TexturePool {
        Shared.shared.defaultTexturePool
    }

    var textureAllocator: TextureAllocating {
        Shared.shared.defaultTextureAllocator
    }

    public var cvMetalTextureCache: CVMetalTextureCache? {
        legacyDevice.textureCache
    }

    public var externalLibraryProviderIdentifiers: [String] {
        Device.externalLibraryProviderIdentifiers()
    }

    @discardableResult
    public func registerExternalLibraryProvider(_ provider: ExternalMTLLibraryProvider) -> Bool {
        Device.registerExternalLibraryProvider(provider)
    }

    func computePipelineState(for kernel: String) -> MTLComputePipelineState? {
        legacyDevice.pipelineState(for: kernel)
    }

    func setComputePipelineState(_ pipeline: MTLComputePipelineState, for kernel: String) {
        legacyDevice.setPipelineState(pipeline, for: kernel)
    }

    func computePipelineState(for identity: KernelFunctionIdentity) -> MTLComputePipelineState? {
        legacyDevice.pipelineState(for: identity)
    }

    func setComputePipelineState(_ pipeline: MTLComputePipelineState, for identity: KernelFunctionIdentity) {
        legacyDevice.setPipelineState(pipeline, for: identity)
    }

    func makeRenderPipelineState(vertex: String,
                                 fragment: String,
                                 pixelFormat: MTLPixelFormat,
                                 sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        try makeRenderPipelineState(
            vertexIdentity: KernelFunctionIdentity(kind: .render, primaryName: vertex),
            fragmentIdentity: KernelFunctionIdentity(kind: .render, primaryName: fragment),
            pixelFormat: pixelFormat,
            sampleCount: sampleCount
        )
    }

    func makeRenderPipelineState(vertexIdentity: KernelFunctionIdentity,
                                 fragmentIdentity: KernelFunctionIdentity,
                                 pixelFormat: MTLPixelFormat,
                                 sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        try makeRenderPipelineState(
            vertexIdentity: vertexIdentity,
            fragmentIdentity: fragmentIdentity,
            renderPass: .singleColor(pixelFormat: pixelFormat, sampleCount: sampleCount)
        )
    }

    func makeRenderPipelineState(vertexIdentity: KernelFunctionIdentity,
                                 fragmentIdentity: KernelFunctionIdentity,
                                 renderPass: RenderPassContract) throws -> MTLRenderPipelineState {
        let key = RenderPipelineCacheKey(
            vertex: vertexIdentity.fingerprint,
            fragment: fragmentIdentity.fingerprint,
            renderPass: renderPass.fingerprint
        )
        renderPipelineLock.lock()
        if let cached = renderPipelines[key] {
            renderPipelineLock.unlock()
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: true)
            return cached
        }
        renderPipelineLock.unlock()

        let descriptor = MTLRenderPipelineDescriptor()
        for attachment in renderPass.colorAttachments where attachment.index < 8 {
            descriptor.colorAttachments[attachment.index].pixelFormat = Self.pixelFormat(from: attachment.pixelFormat) ?? .invalid
        }
        descriptor.rasterSampleCount = renderPass.sampleCount
        descriptor.vertexFunction = try Device.readMTLFunction(vertexIdentity)
        descriptor.fragmentFunction = try Device.readMTLFunction(fragmentIdentity)
        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: false)
            throw HarbethError.renderPipelineState(vertexIdentity.primaryName, fragmentIdentity.primaryName)
        }

        renderPipelineLock.lock()
        renderPipelines[key] = pipelineState
        renderPipelineLock.unlock()
        Shared.shared.performanceMonitor?.recordPipelineCacheLookup("render", hit: false)
        return pipelineState
    }

    private static func pixelFormat(from value: String?) -> MTLPixelFormat? {
        guard let value else { return nil }
        switch value {
        case "rgba8Unorm", String(describing: MTLPixelFormat.rgba8Unorm):
            return .rgba8Unorm
        case "bgra8Unorm", String(describing: MTLPixelFormat.bgra8Unorm):
            return .bgra8Unorm
        case "rgba8Unorm_srgb", String(describing: MTLPixelFormat.rgba8Unorm_srgb):
            return .rgba8Unorm_srgb
        case "bgra8Unorm_srgb", String(describing: MTLPixelFormat.bgra8Unorm_srgb):
            return .bgra8Unorm_srgb
        case "rgba16Float", String(describing: MTLPixelFormat.rgba16Float):
            return .rgba16Float
        case "r8Unorm", String(describing: MTLPixelFormat.r8Unorm):
            return .r8Unorm
        case "rg8Unorm", String(describing: MTLPixelFormat.rg8Unorm):
            return .rg8Unorm
        case "rgba32Float", String(describing: MTLPixelFormat.rgba32Float):
            return .rgba32Float
        case "r16Float", String(describing: MTLPixelFormat.r16Float):
            return .r16Float
        default:
            return nil
        }
    }

    func makeSamplerState(minFilter: MTLSamplerMinMagFilter = .linear,
                          magFilter: MTLSamplerMinMagFilter = .linear,
                          mipFilter: MTLSamplerMipFilter = .notMipmapped,
                          sAddressMode: MTLSamplerAddressMode = .clampToEdge,
                          tAddressMode: MTLSamplerAddressMode = .clampToEdge) -> MTLSamplerState? {
        let key = SamplerCacheKey(
            minFilter: Int(minFilter.rawValue),
            magFilter: Int(magFilter.rawValue),
            mipFilter: Int(mipFilter.rawValue),
            sAddressMode: Int(sAddressMode.rawValue),
            tAddressMode: Int(tAddressMode.rawValue)
        )
        samplerLock.lock()
        if let cached = samplerStates[key] {
            samplerLock.unlock()
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("sampler", hit: true)
            return cached
        }
        samplerLock.unlock()

        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = minFilter
        descriptor.magFilter = magFilter
        descriptor.mipFilter = mipFilter
        descriptor.sAddressMode = sAddressMode
        descriptor.tAddressMode = tAddressMode
        let state = device.makeSamplerState(descriptor: descriptor)
        samplerLock.lock()
        if let state {
            samplerStates[key] = state
        }
        samplerLock.unlock()
        Shared.shared.performanceMonitor?.recordPipelineCacheLookup("sampler", hit: false)
        return state
    }

    func makeSamplerState(_ descriptor: ImageSamplerDescriptor) -> MTLSamplerState? {
        makeSamplerState(
            minFilter: descriptor.minFilter,
            magFilter: descriptor.magFilter,
            mipFilter: descriptor.mipFilter,
            sAddressMode: descriptor.sAddressMode,
            tAddressMode: descriptor.tAddressMode
        )
    }

    func cachedResolvedTexture(for fingerprint: String) -> MTLTexture? {
        imageResolutionLock.lock()
        let key = namespacedImageResolutionCacheKey(for: fingerprint)
        guard let texture = imageResolutionCache[key] else {
            imageResolutionLock.unlock()
            return nil
        }
        imageResolutionCacheOrder.removeAll { $0 == key }
        imageResolutionCacheOrder.append(key)
        imageResolutionLock.unlock()
        return texture
    }

    func storeResolvedTexture(_ texture: MTLTexture, for fingerprint: String) {
        imageResolutionLock.lock()
        let key = namespacedImageResolutionCacheKey(for: fingerprint)
        let textureByteSize = max(texture.allocatedSize, 1)
        guard textureByteSize <= imageResolutionCacheByteLimit else {
            if let oldByteSize = imageResolutionCacheByteSizes.removeValue(forKey: key) {
                imageResolutionCacheByteCount = max(imageResolutionCacheByteCount - oldByteSize, 0)
            }
            imageResolutionCache.removeValue(forKey: key)
            imageResolutionCacheOrder.removeAll { $0 == key }
            imageResolutionLock.unlock()
            return
        }
        if let oldByteSize = imageResolutionCacheByteSizes[key] {
            imageResolutionCacheByteCount = max(imageResolutionCacheByteCount - oldByteSize, 0)
            imageResolutionCacheOrder.removeAll { $0 == key }
            imageResolutionCacheOrder.append(key)
        } else {
            imageResolutionCacheOrder.append(key)
        }
        imageResolutionCache[key] = texture
        imageResolutionCacheByteSizes[key] = textureByteSize
        imageResolutionCacheByteCount += textureByteSize
        while (imageResolutionCacheOrder.count > imageResolutionCacheLimit || imageResolutionCacheByteCount > imageResolutionCacheByteLimit),
              let oldest = imageResolutionCacheOrder.first {
            imageResolutionCacheOrder.removeFirst()
            imageResolutionCache.removeValue(forKey: oldest)
            if let removedByteSize = imageResolutionCacheByteSizes.removeValue(forKey: oldest) {
                imageResolutionCacheByteCount = max(imageResolutionCacheByteCount - removedByteSize, 0)
            }
        }
        imageResolutionLock.unlock()
    }

    func imageResolutionCacheCount() -> Int {
        imageResolutionLock.lock()
        let count = imageResolutionCache.count
        imageResolutionLock.unlock()
        return count
    }

    func setImageResolutionCacheNamespace(_ namespace: String) {
        imageResolutionLock.lock()
        imageResolutionCacheNamespace = namespace
        imageResolutionLock.unlock()
    }

    func currentImageResolutionCacheNamespace() -> String {
        imageResolutionLock.lock()
        let namespace = imageResolutionCacheNamespace
        imageResolutionLock.unlock()
        return namespace
    }

    func bumpImageResolutionCacheNamespace() {
        imageResolutionLock.lock()
        imageResolutionCacheNamespace = UUID().uuidString
        imageResolutionLock.unlock()
    }

    /// Returns a cached RenderPlan for the given fingerprint and marks it as
    /// most-recently-used. `nil` means cache miss.
    func cachedRenderPlan(for fingerprint: String) -> RenderPlan? {
        renderPlanLock.lock()
        guard let plan = renderPlanCache[fingerprint] else {
            renderPlanLock.unlock()
            return nil
        }
        // Move to most-recently-used position.
        renderPlanCacheOrder.removeAll { $0 == fingerprint }
        renderPlanCacheOrder.append(fingerprint)
        renderPlanLock.unlock()
        return plan
    }

    /// Stores a RenderPlan in the LRU cache. When the cache exceeds its
    /// limit, the least-recently-used entries are evicted from the head of
    /// `renderPlanCacheOrder`.
    func storeRenderPlan(_ plan: RenderPlan, for fingerprint: String) {
        renderPlanLock.lock()
        if renderPlanCache[fingerprint] == nil {
            renderPlanCacheOrder.append(fingerprint)
        }
        renderPlanCache[fingerprint] = plan
        while renderPlanCacheOrder.count > renderPlanCacheLimit,
              let oldest = renderPlanCacheOrder.first {
            renderPlanCacheOrder.removeFirst()
            renderPlanCache.removeValue(forKey: oldest)
        }
        renderPlanLock.unlock()
    }

    /// Clears all cached RenderPlans. Wired into `resetCaches()` so that
    /// callers invalidating the underlying device also drop the plan cache.
    func removeAllRenderPlans() {
        renderPlanLock.lock()
        renderPlanCache.removeAll()
        renderPlanCacheOrder.removeAll()
        renderPlanLock.unlock()
    }

    /// Current count of cached RenderPlans (mostly for tests / diagnostics).
    func renderPlanCacheCount() -> Int {
        renderPlanLock.lock()
        let count = renderPlanCache.count
        renderPlanLock.unlock()
        return count
    }

    public func resetCaches() {
        legacyDevice.removePipelineStates()
        legacyDevice.removeFunctionCache()
        renderPipelineLock.lock()
        renderPipelines.removeAll()
        renderPipelineLock.unlock()
        samplerLock.lock()
        samplerStates.removeAll()
        samplerLock.unlock()
        imageResolutionLock.lock()
        imageResolutionCache.removeAll()
        imageResolutionCacheOrder.removeAll()
        imageResolutionCacheByteSizes.removeAll()
        imageResolutionCacheByteCount = 0
        imageResolutionLock.unlock()
        removeAllRenderPlans()
        ImageNode.removeAllOutputContractCachedTextures()
    }

    public func debugCacheSnapshot() -> CacheSnapshot {
        renderPipelineLock.lock()
        let renderCount = renderPipelines.count
        renderPipelineLock.unlock()
        samplerLock.lock()
        let samplerCount = samplerStates.count
        samplerLock.unlock()
        imageResolutionLock.lock()
        let imageResolutionCount = imageResolutionCache.count
        let imageResolutionBytes = imageResolutionCacheByteCount
        imageResolutionLock.unlock()
        renderPlanLock.lock()
        let renderPlanCount = renderPlanCache.count
        renderPlanLock.unlock()
        return CacheSnapshot(
            functionCacheCount: legacyDevice.functionCacheCount,
            computePipelineCount: legacyDevice.pipelineCount,
            renderPipelineCount: renderCount,
            samplerCount: samplerCount,
            imageResolutionCount: imageResolutionCount,
            imageResolutionByteCount: imageResolutionBytes,
            imageResolutionByteLimit: imageResolutionCacheByteLimit,
            renderPlanCount: renderPlanCount,
            hasTexturePool: true,
            hasCVMetalTextureCache: cvMetalTextureCache != nil
        )
    }

    private func namespacedImageResolutionCacheKey(for fingerprint: String) -> String {
        "\(imageResolutionCacheNamespace)||\(fingerprint)"
    }

    private func purgeMemorySensitiveCaches() {
        imageResolutionLock.lock()
        imageResolutionCache.removeAll()
        imageResolutionCacheOrder.removeAll()
        imageResolutionCacheByteSizes.removeAll()
        imageResolutionCacheByteCount = 0
        imageResolutionLock.unlock()
        ImageNode.removeAllOutputContractCachedTextures()
    }
}

public extension HarbethContext {
    struct CacheSnapshot: Sendable, Equatable {
        public let functionCacheCount: Int
        public let computePipelineCount: Int
        public let renderPipelineCount: Int
        public let samplerCount: Int
        public let imageResolutionCount: Int
        public let imageResolutionByteCount: Int
        public let imageResolutionByteLimit: Int
        public let renderPlanCount: Int
        public let hasTexturePool: Bool
        public let hasCVMetalTextureCache: Bool
    }
}

private struct RenderPipelineCacheKey: Hashable {
    let vertex: String
    let fragment: String
    let renderPass: String
}

private struct SamplerCacheKey: Hashable {
    let minFilter: Int
    let magFilter: Int
    let mipFilter: Int
    let sAddressMode: Int
    let tAddressMode: Int
}

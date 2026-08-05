//
//  HarbethContext.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
@preconcurrency import CoreImage
import CoreVideo
@preconcurrency import Metal

#if os(iOS) || os(tvOS)
import UIKit
#endif

public final class HarbethContext: @unchecked Sendable {

    public static let shared = HarbethContext(device: Device())

    let runtimeDevice: Device
    let derivedResourceStore: DerivedResourceStore
    let coreImageContext: CIContext

    public let performanceMonitor = PerformanceMonitor(enabled: false)

    private let executionScheduler: ExecutionScheduler
    private let texturePoolStorage: TexturePool
    private let runtimeStateLock = NSLock()
    private let cvTextureCacheLock = NSLock()
    private var cvTextureCacheStorage: CVMetalTextureCache?
    private var textureAllocationStrategyStorage: TextureAllocationStrategy = .exact
    private var textureAllocatorStorage: TextureAllocator?
    private let pipelineBinaryArchiveStore: PipelineBinaryArchiveStore
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
    /// Value: compiled RenderPlan (a large struct, ~10-50 KB) On hit.
    private var renderPlanCache: [String: RenderPlan] = [:]
    private var renderPlanCacheOrder: [String] = []
    private let renderPlanCacheLimit: Int = 100

    #if os(iOS) || os(tvOS)
    private var memoryWarningObserver: NSObjectProtocol?
    #elseif os(macOS)
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    #endif

    init(device: Device) {
        self.runtimeDevice = device
        self.coreImageContext = CIContext(mtlDevice: device.device)
        self.executionScheduler = ExecutionScheduler(device: device.device)
        self.texturePoolStorage = TexturePool(device: device.device)
        self.pipelineBinaryArchiveStore = PipelineBinaryArchiveStore(device: device.device)
        let physicalMemory = Int(clamping: ProcessInfo.processInfo.physicalMemory)
        self.imageResolutionCacheByteLimit = min(max(physicalMemory / 50, 32 * 1024 * 1024), 256 * 1024 * 1024)
        self.derivedResourceStore = DerivedResourceStore(
            configuration: DerivedResourceCacheConfiguration(
                byteLimit: min(max(physicalMemory / 32, 64 * 1024 * 1024), 384 * 1024 * 1024)
            )
        )
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

    // MARK: - Public device and execution resources

    /// Process-lifetime Metal device shared by both public processing routes.
    public var device: MTLDevice {
        runtimeDevice.device
    }

    /// Creates a single-use command buffer from the current execution generation.
    public func makeCommandBuffer() -> MTLCommandBuffer? {
        executionScheduler.makeCommandBuffer()
    }

    /// Current execution generation used to reject stale host-side work.
    public var executionGeneration: UInt64 {
        executionScheduler.generation
    }

    public func isCurrentExecutionGeneration(_ generation: UInt64) -> Bool {
        executionScheduler.generation == generation
    }

    /// Cancels queued CPU operations, rotates the command queue and clears
    /// memory-sensitive runtime caches. Already committed GPU work remains
    /// owned by Metal and is not synchronously cancelled.
    @discardableResult
    public func recoverExecution() -> UInt64 {
        let generation = executionScheduler.recover()
        resetCaches()
        texturePoolStorage.purgeAllTexturesSync()
        flushCVMetalTextureCache()
        return generation
    }

    /// Core Video texture cache for advanced pixel-buffer interop.
    public var cvMetalTextureCache: CVMetalTextureCache? {
        cvTextureCacheLock.lock()
        defer { cvTextureCacheLock.unlock() }
        if let cvTextureCacheStorage {
            return cvTextureCacheStorage
        }
        var textureCache: CVMetalTextureCache?
        #if !targetEnvironment(simulator)
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        #endif
        cvTextureCacheStorage = textureCache
        return textureCache
    }

    public var maxConcurrentRenderTasks: Int {
        get { executionScheduler.maxConcurrentOperationCount }
        set { executionScheduler.maxConcurrentOperationCount = newValue }
    }

    // MARK: - Public resource policy

    /// Allocation policy for subsequent render-plan compilation and execution.
    /// Changing the value invalidates cached render plans.
    public var textureAllocationStrategy: TextureAllocationStrategy {
        get {
            runtimeStateLock.lock()
            defer { runtimeStateLock.unlock() }
            return textureAllocationStrategyStorage
        }
        set {
            runtimeStateLock.lock()
            let changed = textureAllocationStrategyStorage != newValue
            textureAllocationStrategyStorage = newValue
            textureAllocatorStorage = nil
            runtimeStateLock.unlock()
            if changed {
                removeAllRenderPlans()
            }
        }
    }

    // MARK: - Public diagnostics

    public var enablePerformanceMonitor: Bool {
        get { performanceMonitor.isEnabled }
        set {
            performanceMonitor.setupEnablePerformanceMonitor(newValue)
            if !newValue {
                performanceMonitor.clearAllMetrics()
            }
        }
    }

    // MARK: - Public Metal library support

    public var externalLibraryProviderIdentifiers: [String] {
        Device.externalLibraryProviderIdentifiers()
    }

    @discardableResult
    public func registerExternalLibraryProvider(_ provider: ExternalMTLLibraryProvider) -> Bool {
        Device.registerExternalLibraryProvider(provider)
    }

    public func externalLibraryRegistrySnapshot() -> [ExternalLibraryProviderSnapshot] {
        Device.externalLibraryRegistrySnapshot(on: device)
    }

    public func externalLibraryRegistryDebugDescription() -> String {
        Device.externalLibraryRegistryDebugDescription(on: device)
    }

    public func capabilityReport(_ capability: C7MetalCapability) -> C7MetalCapabilityReport {
        Device.metalCapabilityReport(capability, on: device)
    }

    public func makeMetalFunction(named name: String) throws -> MTLFunction {
        try Device.readMTLFunction(name)
    }

    // MARK: - Internal runtime resources

    /// Current command queue. Internal code must not retain it across recovery.
    var commandQueue: MTLCommandQueue {
        executionScheduler.commandQueue
    }

    var texturePool: TexturePool {
        texturePoolStorage
    }

    var textureAllocator: TextureAllocator {
        get {
            runtimeStateLock.lock()
            if let allocator = textureAllocatorStorage {
                runtimeStateLock.unlock()
                return allocator
            }
            let allocator = textureAllocationStrategyStorage.makeAllocator(
                texturePool: texturePoolStorage,
                on: device
            )
            textureAllocatorStorage = allocator
            runtimeStateLock.unlock()
            return allocator
        }
        set {
            setTextureAllocatorForTesting(newValue)
        }
    }

    var renderOperationQueue: OperationQueue {
        executionScheduler.operationQueue
    }

    @discardableResult
    func submitRenderOperation(
        sourceIdentifier: String,
        policy: RenderSubmissionPolicy,
        execute: @escaping @Sendable (RenderSubmissionContext) -> Void,
        onDiscard: @escaping @Sendable (RenderSubmissionDiscardReason) -> Void
    ) -> RenderSubmissionHandle {
        executionScheduler.submit(
            sourceIdentifier: sourceIdentifier,
            policy: policy,
            execute: execute,
            onDiscard: onDiscard
        )
    }

    var colorSpace: CGColorSpace {
        runtimeDevice.colorSpace
    }

    var workingColorSpace: CGColorSpace? {
        runtimeDevice.workingColorSpace
    }

    func recycleCommandBuffer(_ commandBuffer: MTLCommandBuffer) {
        // Metal command buffers are single-use. This method keeps cleanup call
        // sites explicit without pretending buffers can be returned to a pool.
    }

    private func flushCVMetalTextureCache() {
        cvTextureCacheLock.lock()
        defer { cvTextureCacheLock.unlock() }
        #if !targetEnvironment(simulator)
        if let cvTextureCacheStorage {
            CVMetalTextureCacheFlush(cvTextureCacheStorage, 0)
        }
        #endif
    }

    private var hasCVMetalTextureCache: Bool {
        cvTextureCacheLock.lock()
        defer { cvTextureCacheLock.unlock() }
        return cvTextureCacheStorage != nil
    }

    // MARK: - Internal pipeline and cache implementation

    func computePipelineState(for kernel: String) -> MTLComputePipelineState? {
        runtimeDevice.pipelineState(for: kernel)
    }

    func setComputePipelineState(_ pipeline: MTLComputePipelineState, for kernel: String) {
        runtimeDevice.setPipelineState(pipeline, for: kernel)
    }

    func computePipelineState(for identity: KernelFunctionIdentity) -> MTLComputePipelineState? {
        runtimeDevice.pipelineState(for: identity)
    }

    func setComputePipelineState(_ pipeline: MTLComputePipelineState, for identity: KernelFunctionIdentity) {
        runtimeDevice.setPipelineState(pipeline, for: identity)
    }

    func makeComputePipelineState(identity: KernelFunctionIdentity) throws -> MTLComputePipelineState {
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.computeFunction = try Device.readMTLFunction(identity)
        pipelineBinaryArchiveStore.attach(to: descriptor)
        do {
            return try device.makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
        } catch {
            throw HarbethError.computePipelineState(identity.primaryName)
        }
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
            performanceMonitor.recordPipelineCacheLookup("render", hit: true)
            return cached
        }
        renderPipelineLock.unlock()

        let descriptor = MTLRenderPipelineDescriptor()
        for attachment in renderPass.colorAttachments where attachment.index < 8 {
            guard let colorAttachment = descriptor.colorAttachments[attachment.index] else { continue }
            colorAttachment.pixelFormat = Self.pixelFormat(from: attachment.pixelFormat) ?? .invalid
            if attachment.index == 0, renderPass.blendMode == .premultipliedSourceOver {
                colorAttachment.isBlendingEnabled = true
                colorAttachment.rgbBlendOperation = .add
                colorAttachment.alphaBlendOperation = .add
                colorAttachment.sourceRGBBlendFactor = .one
                colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                colorAttachment.sourceAlphaBlendFactor = .one
                colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }
        descriptor.rasterSampleCount = renderPass.sampleCount
        descriptor.vertexFunction = try Device.readMTLFunction(vertexIdentity)
        descriptor.fragmentFunction = try Device.readMTLFunction(fragmentIdentity)
        pipelineBinaryArchiveStore.attach(to: descriptor)
        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            performanceMonitor.recordPipelineCacheLookup("render", hit: false)
            throw HarbethError.renderPipelineState(vertexIdentity.primaryName, fragmentIdentity.primaryName)
        }

        renderPipelineLock.lock()
        renderPipelines[key] = pipelineState
        renderPipelineLock.unlock()
        performanceMonitor.recordPipelineCacheLookup("render", hit: false)
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
            performanceMonitor.recordPipelineCacheLookup("sampler", hit: true)
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
        performanceMonitor.recordPipelineCacheLookup("sampler", hit: false)
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

    // MARK: - Public cache and archive governance

    public func resetCaches() {
        runtimeDevice.removePipelineStates()
        runtimeDevice.removeFunctionCache()
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
        derivedResourceStore.invalidate()
    }

    public func configurePipelineBinaryArchive(_ configuration: PipelineBinaryArchiveConfiguration) throws {
        try pipelineBinaryArchiveStore.configure(configuration)
        runtimeDevice.removePipelineStates()
        renderPipelineLock.lock()
        renderPipelines.removeAll()
        renderPipelineLock.unlock()
    }

    public func serializePipelineBinaryArchive(to url: URL? = nil) throws {
        try pipelineBinaryArchiveStore.serialize(to: url)
    }

    public var pipelineBinaryArchiveSnapshot: PipelineBinaryArchiveSnapshot {
        pipelineBinaryArchiveStore.snapshot()
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
        let derivedSnapshot = derivedResourceStore.snapshot()
        let texturePoolSnapshot = texturePoolStorage.statistics
        return CacheSnapshot(
            functionCacheCount: runtimeDevice.functionCacheCount,
            computePipelineCount: runtimeDevice.pipelineCount,
            renderPipelineCount: renderCount,
            samplerCount: samplerCount,
            imageResolutionCount: imageResolutionCount,
            imageResolutionByteCount: imageResolutionBytes,
            imageResolutionByteLimit: imageResolutionCacheByteLimit,
            renderPlanCount: renderPlanCount,
            derivedResourceCount: derivedSnapshot.entryCount,
            derivedResourceByteCount: derivedSnapshot.byteCount,
            derivedResourceByteLimit: derivedSnapshot.byteLimit,
            texturePoolCount: texturePoolSnapshot.currentTextureCount,
            texturePoolByteCount: texturePoolSnapshot.currentMemoryUsage,
            texturePoolByteLimit: texturePoolSnapshot.maxMemoryUsage,
            allocationStrategy: textureAllocationStrategy,
            executionGeneration: executionGeneration,
            hasTexturePool: true,
            hasCVMetalTextureCache: hasCVMetalTextureCache
        )
    }

    // MARK: - Internal cache maintenance

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
        derivedResourceStore.invalidate()
    }

    // MARK: - Public texture pool governance

    public func prewarmTexturePool(
        resolutions: [(width: Int, height: Int, pixelFormat: MTLPixelFormat)],
        count: Int = 2
    ) {
        texturePoolStorage.prewarm(resolutions: resolutions, count: count)
    }

    public func prewarmTexturePool(
        reservations: [RenderTextureReservation],
        fallbackPixelFormat: MTLPixelFormat,
        defaultCount: Int = 1
    ) {
        texturePoolStorage.prewarm(
            requests: makePrewarmRequests(
                from: reservations,
                fallbackPixelFormat: fallbackPixelFormat,
                defaultCount: defaultCount
            )
        )
    }

    func prewarmTexturePoolSync(
        reservations: [RenderTextureReservation],
        fallbackPixelFormat: MTLPixelFormat,
        defaultCount: Int = 1
    ) {
        texturePoolStorage.prewarmSync(
            requests: makePrewarmRequests(
                from: reservations,
                fallbackPixelFormat: fallbackPixelFormat,
                defaultCount: defaultCount
            )
        )
    }

    public var texturePoolStatistics: TexturePoolStatistics {
        texturePoolStorage.statistics
    }

    public func resetTexturePoolStatistics() {
        texturePoolStorage.resetStatisticsSync()
    }

    private func makePrewarmRequests(
        from reservations: [RenderTextureReservation],
        fallbackPixelFormat: MTLPixelFormat,
        defaultCount: Int
    ) -> [TexturePool.PrewarmRequest] {
        reservations.map { reservation in
            TexturePool.PrewarmRequest(
                width: reservation.size.width,
                height: reservation.size.height,
                pixelFormat: reservation.pixelFormat.metalPixelFormat ?? fallbackPixelFormat,
                count: max(defaultCount, reservation.count)
            )
        }
    }

    func setTextureAllocatorForTesting(_ allocator: TextureAllocator) {
        runtimeStateLock.lock()
        textureAllocatorStorage = allocator
        runtimeStateLock.unlock()
        removeAllRenderPlans()
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
        public let derivedResourceCount: Int
        public let derivedResourceByteCount: Int
        public let derivedResourceByteLimit: Int
        public let texturePoolCount: Int
        public let texturePoolByteCount: Int
        public let texturePoolByteLimit: Int
        public let allocationStrategy: TextureAllocationStrategy
        public let executionGeneration: UInt64
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

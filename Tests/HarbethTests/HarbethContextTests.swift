import XCTest
import Metal
import CoreVideo
@testable import Harbeth

final class HarbethContextTests: XCTestCase {

    func testContextCachesComputeRenderAndSamplerState() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let context = Shared.shared.defaultContext
        context.resetCaches()

        _ = context.makeSamplerState()
        _ = context.makeSamplerState()
        _ = context.makeSamplerState(.nearest)
        _ = context.makeSamplerState(.nearest)

        let snapshot = context.debugCacheSnapshot()
        XCTAssertEqual(snapshot.samplerCount, 2)
        XCTAssertNotNil(context.commandQueue)
    }

    func testContextCachesComputePipelineByKernelIdentity() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let context = Shared.shared.defaultContext
        context.resetCaches()
        let identity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "C7Brightness",
            librarySource: .automatic
        )
        let defaultLibraryIdentity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "C7Brightness",
            librarySource: .defaultLibrary
        )

        let first = try Compute.makeComputePipelineState(with: identity)
        let second = try Compute.makeComputePipelineState(with: identity)
        context.setComputePipelineState(first, for: defaultLibraryIdentity)
        let snapshot = context.debugCacheSnapshot()

        XCTAssertTrue(first === second)
        XCTAssertEqual(snapshot.computePipelineCount, 2)

        context.resetCaches()
        XCTAssertEqual(context.debugCacheSnapshot().computePipelineCount, 0)
    }

    func testContextCachesRenderPipelineByKernelIdentity() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let context = Shared.shared.defaultContext
        context.resetCaches()
        let vertex = KernelFunctionIdentity(
            kind: .render,
            primaryName: "basicVertex",
            librarySource: .automatic
        )
        let fragment = KernelFunctionIdentity(
            kind: .render,
            primaryName: "sepiaFragment",
            librarySource: .automatic
        )
        let sourceFallbackFragment = KernelFunctionIdentity(
            kind: .render,
            primaryName: "sepiaFragment",
            librarySource: .sourceFallback("render-shader-source")
        )

        let first = try context.makeRenderPipelineState(
            vertexIdentity: vertex,
            fragmentIdentity: fragment,
            pixelFormat: .rgba8Unorm
        )
        let second = try context.makeRenderPipelineState(
            vertexIdentity: vertex,
            fragmentIdentity: fragment,
            pixelFormat: .rgba8Unorm
        )
        _ = try context.makeRenderPipelineState(
            vertexIdentity: vertex,
            fragmentIdentity: sourceFallbackFragment,
            pixelFormat: .rgba8Unorm
        )

        XCTAssertTrue(first === second)
        XCTAssertEqual(context.debugCacheSnapshot().renderPipelineCount, 2)
    }

    func testContextCachesMetalFunctionByKernelIdentity() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let context = Shared.shared.defaultContext
        context.resetCaches()
        let identity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "C7Brightness",
            librarySource: .automatic
        )

        let first = try Device.readMTLFunction(identity)
        let second = try Device.readMTLFunction(identity)

        XCTAssertTrue(first === second)
        XCTAssertEqual(context.debugCacheSnapshot().functionCacheCount, 1)

        context.resetCaches()
        XCTAssertEqual(context.debugCacheSnapshot().functionCacheCount, 0)
    }

    func testTexturePoolReusesExactTexture() throws {
        let texture = try TextureLoader.makeTexture(width: 4, height: 4, identifier: "context-pool")
        Shared.shared.defaultTexturePool.enqueueTextureSync(texture)
        let reused = try TextureLoader.makeTexture(width: 4, height: 4, identifier: "context-pool")
        XCTAssertTrue(texture === reused)
    }

    func testSharedOwnsDefaultRuntimeAndContextBridgesToIt() {
        Shared.shared.deinitDevice()

        let device = Shared.shared.defaultDevice
        let context = Shared.shared.defaultContext

        XCTAssertTrue(Shared.shared.hasDevice)
        XCTAssertTrue(Shared.shared.hasContext)
        XCTAssertTrue(context === HarbethContext.shared)
        XCTAssertTrue(context.device === device.device)
        XCTAssertTrue(context.commandQueue === device.commandQueue)
        XCTAssertTrue(context.texturePool === Shared.shared.defaultTexturePool)
        XCTAssertTrue((context.textureAllocator as AnyObject) === (Shared.shared.defaultTextureAllocator as AnyObject))
    }

    func testSharedProvidesTextureAllocatorBackedByDefaultTexturePool() {
        Shared.shared.deinitDevice()

        let allocator = Shared.shared.defaultTextureAllocator
        let allocatorAgain = Shared.shared.defaultTextureAllocator

        XCTAssertTrue((allocator as AnyObject) === (allocatorAgain as AnyObject))
        XCTAssertTrue(allocator is TexturePoolAllocator)
        XCTAssertTrue((allocator as? TexturePoolAllocator)?.texturePool === Shared.shared.defaultTexturePool)
    }

    func testSharedDefaultTextureAllocationStrategyRebuildsAllocator() {
        Shared.shared.deinitDevice()
        Shared.shared.defaultTextureAllocationStrategy = .exact
        defer {
            Shared.shared.defaultTextureAllocationStrategy = .exact
            Shared.shared.deinitDevice()
        }

        let exactAllocator = Shared.shared.defaultTextureAllocator
        let pool = Shared.shared.defaultTexturePool

        Shared.shared.defaultTextureAllocationStrategy = .tolerant
        let tolerantAllocator = Shared.shared.defaultTextureAllocator

        XCTAssertEqual(exactAllocator.strategy, .exact)
        XCTAssertEqual(Shared.shared.defaultTextureAllocationStrategy, .tolerant)
        XCTAssertEqual(tolerantAllocator.strategy, .tolerant)
        XCTAssertTrue((tolerantAllocator as? TexturePoolAllocator)?.texturePool === pool)
        XCTAssertFalse((exactAllocator as AnyObject) === (tolerantAllocator as AnyObject))

        Shared.shared.defaultTextureAllocationStrategy = .exact
        let exactAllocatorAgain = Shared.shared.defaultTextureAllocator

        XCTAssertEqual(exactAllocatorAgain.strategy, .exact)
        XCTAssertTrue((exactAllocatorAgain as? TexturePoolAllocator)?.texturePool === pool)
        XCTAssertFalse((tolerantAllocator as AnyObject) === (exactAllocatorAgain as AnyObject))
    }

    func testSharedHeapBackedDefaultTextureAllocationStrategyResolvesAgainstCurrentDeviceCapability() {
        Shared.shared.deinitDevice()
        Shared.shared.defaultTextureAllocationStrategy = .heapBacked
        defer {
            Shared.shared.defaultTextureAllocationStrategy = .exact
            Shared.shared.deinitDevice()
        }

        let report = Device.metalCapabilityReport(.heapTexturePool, on: Shared.shared.currentMetalDevice)
        let allocator = Shared.shared.defaultTextureAllocator

        XCTAssertEqual(
            allocator.strategy,
            TextureAllocationStrategy.heapBacked.resolvedStrategy(
                heapTexturePoolSupported: report.isSupported
            )
        )
        XCTAssertTrue((allocator as? TexturePoolAllocator)?.texturePool === Shared.shared.defaultTexturePool)
        let snapshot = allocator.makeSnapshot()
        XCTAssertEqual(snapshot.requestedAllocationStrategy, .heapBacked)
        XCTAssertEqual(
            snapshot.allocationFallbackReason,
            TextureAllocationStrategy.heapBacked.fallbackReason(
                heapTexturePoolSupported: report.isSupported
            )
        )
        XCTAssertEqual(snapshot.allocationResolution.requested, .heapBacked)
        XCTAssertEqual(snapshot.allocationResolution.resolved, allocator.strategy)
        XCTAssertEqual(
            snapshot.allocationResolution.isFallback,
            report.isSupported == false
        )
    }

    func testTexturePoolPrewarmSyncHonorsPerRequestCounts() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let pool = TexturePool()
        pool.prewarmSync(
            requests: [
                .init(width: 11, height: 7, pixelFormat: .rgba8Unorm, count: 1),
                .init(width: 19, height: 13, pixelFormat: .rgba8Unorm, count: 3)
            ]
        )

        XCTAssertNotNil(pool.dequeueExactTexture(width: 11, height: 7, pixelFormat: .rgba8Unorm))
        XCTAssertNil(pool.dequeueExactTexture(width: 11, height: 7, pixelFormat: .rgba8Unorm))

        XCTAssertNotNil(pool.dequeueExactTexture(width: 19, height: 13, pixelFormat: .rgba8Unorm))
        XCTAssertNotNil(pool.dequeueExactTexture(width: 19, height: 13, pixelFormat: .rgba8Unorm))
        XCTAssertNotNil(pool.dequeueExactTexture(width: 19, height: 13, pixelFormat: .rgba8Unorm))
        XCTAssertNil(pool.dequeueExactTexture(width: 19, height: 13, pixelFormat: .rgba8Unorm))
    }

    func testSharedPrewarmTexturePoolSyncPreservesReservationCounts() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let small = C7Size(width: 23, height: 11)
        let large = C7Size(width: 29, height: 17)
        Shared.shared.prewarmTexturePoolSync(
            reservations: [
                .init(stageIndices: [0], size: small, pixelFormat: .rgba8Unorm, reason: .transientReuse, count: 1),
                .init(stageIndices: [1, 2, 3], size: large, pixelFormat: .rgba8Unorm, reason: .persistentOutput, count: 3)
            ],
            fallbackPixelFormat: .rgba8Unorm,
            defaultCount: 1
        )

        XCTAssertNotNil(Shared.shared.defaultTexturePool.dequeueExactTexture(width: small.width, height: small.height, pixelFormat: .rgba8Unorm))
        XCTAssertNil(Shared.shared.defaultTexturePool.dequeueExactTexture(width: small.width, height: small.height, pixelFormat: .rgba8Unorm))

        XCTAssertNotNil(Shared.shared.defaultTexturePool.dequeueExactTexture(width: large.width, height: large.height, pixelFormat: .rgba8Unorm))
        XCTAssertNotNil(Shared.shared.defaultTexturePool.dequeueExactTexture(width: large.width, height: large.height, pixelFormat: .rgba8Unorm))
        XCTAssertNotNil(Shared.shared.defaultTexturePool.dequeueExactTexture(width: large.width, height: large.height, pixelFormat: .rgba8Unorm))
        XCTAssertNil(Shared.shared.defaultTexturePool.dequeueExactTexture(width: large.width, height: large.height, pixelFormat: .rgba8Unorm))
    }

    func testTolerantTextureAllocatorStillReusesOversizedUnormTexture() throws {
        let pool = TexturePool()
        let allocator = TolerantTextureAllocator(texturePool: pool)
        let texture = try TextureLoader.makeTexture(width: 12, height: 12, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "allocator-unorm-tolerance")
        pool.enqueueTextureSync(texture)

        let reused = allocator.dequeueTexture(
            width: 10,
            height: 10,
            pixelFormat: .rgba8Unorm,
            allowsSizeTolerance: true
        )

        XCTAssertTrue(reused === texture)
        XCTAssertEqual(allocator.makeSnapshot().allocatorDecisions, ["dequeueToleranceMatch"])
    }

    func testTolerantTextureAllocatorForcesExactMatchForHighPrecisionTexture() throws {
        let pool = TexturePool()
        let allocator = TolerantTextureAllocator(texturePool: pool)
        let texture = try TextureLoader.makeTexture(width: 12, height: 12, options: [
            .texturePixelFormat: MTLPixelFormat.rgba16Float
        ], identifier: "allocator-high-precision-exact")
        pool.enqueueTextureSync(texture)

        let reused = allocator.dequeueTexture(
            width: 10,
            height: 10,
            pixelFormat: .rgba16Float,
            allowsSizeTolerance: true
        )

        XCTAssertNil(reused)
        XCTAssertEqual(
            allocator.makeSnapshot().allocatorDecisions,
            ["highPrecisionForcesExactMatch", "dequeueExactMatch"]
        )
    }

    func testTolerantTextureAllocatorLeaseForcesExactMatchForHighPrecisionTexture() throws {
        let pool = TexturePool()
        let allocator = TolerantTextureAllocator(texturePool: pool)
        let texture = try TextureLoader.makeTexture(width: 12, height: 12, options: [
            .texturePixelFormat: MTLPixelFormat.rgba16Float
        ], identifier: "allocator-high-precision-lease")
        pool.enqueueTextureSync(texture)

        let lease = allocator.dequeueTextureLease(
            width: 10,
            height: 10,
            pixelFormat: .rgba16Float,
            allowsSizeTolerance: true,
            logicalExtent: C7Size(width: 10, height: 10)
        )

        XCTAssertNil(lease)
        XCTAssertEqual(
            allocator.makeSnapshot().allocatorDecisions,
            ["highPrecisionForcesExactMatch", "leaseExactMatch"]
        )
    }

    func testHeapBackedAllocationStrategyFallsBackToExactWhenCapabilityIsUnavailable() {
        let pool = TexturePool()

        XCTAssertEqual(
            TextureAllocationStrategy.heapBacked.resolvedStrategy(heapTexturePoolSupported: false),
            .exact
        )
        XCTAssertEqual(
            TextureAllocationStrategy.heapBacked.fallbackReason(heapTexturePoolSupported: false),
            "unsupportedHeapTexturePoolCapabilityFallbackToExact"
        )
        XCTAssertTrue(
            TextureAllocationStrategy.heapBacked.makeAllocator(
                texturePool: pool,
                heapTexturePoolSupported: false
            ) is ExactTextureAllocator
        )
    }

    func testHeapBackedAllocationStrategyCreatesHeapAllocatorWhenCapabilityIsAvailable() {
        let pool = TexturePool()

        XCTAssertEqual(
            TextureAllocationStrategy.heapBacked.resolvedStrategy(heapTexturePoolSupported: true),
            .heapBacked
        )
        XCTAssertNil(
            TextureAllocationStrategy.heapBacked.fallbackReason(heapTexturePoolSupported: true)
        )
        XCTAssertTrue(
            TextureAllocationStrategy.heapBacked.makeAllocator(
                texturePool: pool,
                heapTexturePoolSupported: true
            ) is HeapBackedTextureAllocator
        )
    }

    func testSharedDeinitDeviceResetsDefaultRuntime() {
        _ = Shared.shared.defaultDevice
        _ = Shared.shared.defaultContext
        _ = Shared.shared.defaultTexturePool

        XCTAssertTrue(Shared.shared.hasDevice)
        XCTAssertTrue(Shared.shared.hasContext)

        Shared.shared.deinitDevice()

        XCTAssertFalse(Shared.shared.hasDevice)
        XCTAssertFalse(Shared.shared.hasContext)

        let newDevice = Shared.shared.defaultDevice
        let newContext = Shared.shared.defaultContext
        XCTAssertTrue(Shared.shared.hasDevice)
        XCTAssertTrue(Shared.shared.hasContext)
        XCTAssertTrue(newContext.device === newDevice.device)
    }

    func testPixelBufferBackedTextureRetainsOwnerReference() throws {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferWidthKey: 2,
                kCVPixelBufferHeightKey: 2,
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA
            ] as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Expected pixel buffer.")
            return
        }

        let texture = try TextureLoader(with: pixelBuffer).texture
        let owner = TextureOwnerRegistry.owner(for: texture)
        XCTAssertNotNil(owner)
    }

    func testPlaneTexturesRetainOwnerReference() throws {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            4,
            4,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            [
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:],
                kCVPixelBufferWidthKey: 4,
                kCVPixelBufferHeightKey: 4,
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ] as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let pixelBuffer else {
            XCTFail("Expected pixel buffer.")
            return
        }

        let textures = pixelBuffer.c7.createPlaneTextures()
        XCTAssertEqual(textures.count, 2)
        XCTAssertNotNil(TextureOwnerRegistry.owner(for: textures[0]))
        XCTAssertNotNil(TextureOwnerRegistry.owner(for: textures[1]))
    }

    func testPerformanceMonitorTracksRenderContractDecisions() {
        let monitor = PerformanceMonitor(enabled: true)
        let identifier = "contract-monitor"
        let plan = GraphCompiler.compile(
            filters: [C7Brightness(brightness: 0.1), C7Resize(width: 2, height: 2)],
            inputSize: C7Size(width: 4, height: 4),
            outputContract: RenderOutputContract(
                alpha: .forcePremultiply,
                colorSpace: ImageColorSpaceContract(name: "sRGB", preservesInput: false),
                pixelFormat: PixelFormatContract(pixelFormat: .rgba8Unorm, preservesInput: false)
            )
        )

        monitor.beginMonitoring(identifier)
        monitor.recordRenderStageCount(identifier, stageCount: plan.diagnostics.stageCount)
        monitor.recordRenderOptimizationPlan(identifier, plan: plan.diagnostics.optimizationPlan)
        monitor.recordAlphaConversion(identifier, contract: plan.diagnostics.outputContract.alpha)
        monitor.recordColorConversion(identifier, contract: plan.diagnostics.outputContract.colorSpace)
        monitor.recordPixelFormatConversion(identifier, from: .bgra8Unorm, to: .rgba8Unorm)
        _ = monitor.endMonitoring(identifier)

        let summary = monitor.getSummary()
        XCTAssertGreaterThan(summary.totalOptimizerDecisions, 0)
        XCTAssertGreaterThan(summary.totalTextureLifecycleDecisions, 0)
        XCTAssertEqual(summary.totalAlphaConversions, 1)
        XCTAssertEqual(summary.totalColorConversions, 1)
        XCTAssertEqual(summary.totalPixelFormatConversions, 1)
    }

    func testPerformanceMonitorTracksImageResolutionCacheLookups() {
        let monitor = PerformanceMonitor(enabled: true)

        monitor.recordImageResolutionCacheLookup("image-node", hit: false)
        monitor.recordImageResolutionCacheLookup("image-node", hit: true)

        let summary = monitor.getSummary()
        XCTAssertEqual(summary.totalImageResolutionCacheMisses, 1)
        XCTAssertEqual(summary.totalImageResolutionCacheHits, 1)
        XCTAssertEqual(summary.imageResolutionCacheHitRate, 0.5)
    }

    func testImageResolutionCacheRespectsLRULimit() throws {
        let context = Shared.shared.defaultContext
        context.resetCaches()
        context.setImageResolutionCacheNamespace("lru-limit")

        for index in 0..<70 {
            let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "image-resolution-lru-\(index)")
            context.storeResolvedTexture(texture, for: "fingerprint-\(index)")
        }

        XCTAssertEqual(context.imageResolutionCacheCount(), 64)
        XCTAssertNil(context.cachedResolvedTexture(for: "fingerprint-0"))
        XCTAssertNil(context.cachedResolvedTexture(for: "fingerprint-5"))
        XCTAssertNotNil(context.cachedResolvedTexture(for: "fingerprint-69"))
    }

    func testImageResolutionCacheNamespaceIsolated() throws {
        let context = Shared.shared.defaultContext
        context.resetCaches()
        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "image-resolution-namespace")

        context.setImageResolutionCacheNamespace("namespace-A")
        context.storeResolvedTexture(texture, for: "shared-fingerprint")
        XCTAssertNotNil(context.cachedResolvedTexture(for: "shared-fingerprint"))

        context.setImageResolutionCacheNamespace("namespace-B")
        XCTAssertNil(context.cachedResolvedTexture(for: "shared-fingerprint"))

        context.setImageResolutionCacheNamespace("namespace-A")
        XCTAssertNotNil(context.cachedResolvedTexture(for: "shared-fingerprint"))
    }

    func testBumpImageResolutionCacheNamespaceInvalidatesCurrentView() throws {
        let context = Shared.shared.defaultContext
        context.resetCaches()
        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "image-resolution-bump")

        context.setImageResolutionCacheNamespace("before-bump")
        context.storeResolvedTexture(texture, for: "fingerprint")
        let previousNamespace = context.currentImageResolutionCacheNamespace()

        context.bumpImageResolutionCacheNamespace()

        XCTAssertNotEqual(context.currentImageResolutionCacheNamespace(), previousNamespace)
        XCTAssertNil(context.cachedResolvedTexture(for: "fingerprint"))
    }

    func testPerformanceMonitorTracksPreviewHostTelemetry() {
        let monitor = PerformanceMonitor(enabled: true)
        let identifier = "preview-host-monitor"

        monitor.beginMonitoring(identifier)
        monitor.recordPreviewHostStrategy(identifier, strategy: .sampleBufferPassthroughHost)
        monitor.recordPreviewHostStrategy(identifier, strategy: .sampleBufferRematerializedHost)
        monitor.recordPreviewHostEnqueue(identifier)
        monitor.recordPreviewHostEnqueue(identifier)
        monitor.recordPreviewHostRecovery(identifier)
        monitor.recordPreviewHostFallbackToMetal(identifier)
        monitor.recordPreviewHostVisibilityPause(identifier)
        monitor.recordPreviewHostVisibilityResume(identifier)
        monitor.recordPreviewHostLifecyclePause(identifier, reason: .applicationInactive)
        monitor.recordPreviewHostLifecycleResume(identifier)
        monitor.recordPreviewHostFailure(identifier, reason: .sampleBufferEnqueueFailed)
        monitor.recordPreviewHostExecution(
            identifier,
            report: PreviewHostExecutionReport(
                predictedStrategy: .sampleBufferPassthroughHost,
                actualBackingKind: .sampleBufferDisplayLayer,
                actualResolvedHostStrategy: .sampleBufferPassthroughHost,
                payloadMode: .passthrough,
                state: .sampleBufferActive,
                enqueueCount: 2,
                lifecyclePauseCount: 1,
                lifecycleResumeCount: 1,
                visibilityPauseCount: 1,
                visibilityResumeCount: 1,
                strategySwitchCount: 1,
                activationCount: 1,
                deactivationCount: 0,
                recoveryCount: 1,
                fallbackCount: 1,
                failureCountsByReason: [PreviewHostFailureReason.sampleBufferEnqueueFailed.rawValue: 1]
            )
        )
        monitor.recordPreviewHostFleetSnapshot(
            identifier,
            snapshot: PreviewHostFleetSnapshot(
                activeHostCount: 2,
                activeSampleBufferHostCount: 1,
                activeMetalHostCount: 1,
                suspendedHostCount: 1,
                recoveringHostCount: 0,
                fallbackHostCount: 1,
                maxConcurrentSampleBufferHosts: 3,
                totalStrategySwitchCount: 2,
                totalActivationCount: 2,
                totalDeactivationCount: 1,
                totalRecoveryCount: 1,
                totalFallbackCount: 1,
                totalLifecycleSuspensionCount: 1,
                totalVisibilitySuspensionCount: 1,
                failureCountsByReason: [PreviewHostFailureReason.sampleBufferEnqueueFailed.rawValue: 1]
            )
        )
        monitor.recordPreviewHostPoolSnapshot(
            identifier,
            snapshot: SampleBufferPreviewHostPoolSnapshot(
                activeLeaseCount: 2,
                pooledLayerCount: 1,
                totalTakeCount: 3,
                totalReuseCount: 1,
                totalReturnCount: 1,
                totalFlushCount: 2,
                totalFlushAndRemoveImageCount: 1,
                totalRecoveryCount: 1,
                totalFallbackToMetalCount: 1,
                totalVisibilityPauseCount: 1,
                totalVisibilityResumeCount: 1,
                totalLifecyclePauseCount: 1,
                totalLifecycleResumeCount: 1
            )
        )
        _ = monitor.endMonitoring(identifier)

        let summary = monitor.getSummary()
        XCTAssertEqual(summary.totalPreviewHostPassthroughStrategyDecisions, 1)
        XCTAssertEqual(summary.totalPreviewHostRematerializedStrategyDecisions, 1)
        XCTAssertEqual(summary.totalPreviewHostEnqueues, 2)
        XCTAssertEqual(summary.totalPreviewHostRecoveries, 1)
        XCTAssertEqual(summary.totalPreviewHostFallbacks, 1)
        XCTAssertEqual(summary.totalPreviewHostVisibilityPauses, 1)
        XCTAssertEqual(summary.totalPreviewHostVisibilityResumes, 1)
        XCTAssertEqual(summary.totalPreviewHostLifecyclePauses, 1)
        XCTAssertEqual(summary.totalPreviewHostLifecycleResumes, 1)
        XCTAssertEqual(summary.totalPreviewHostFailures, 1)
        XCTAssertEqual(summary.totalPreviewHostStrategySwitches, 1)
        XCTAssertEqual(summary.totalPreviewHostActivations, 1)
        XCTAssertEqual(summary.totalPreviewHostDeactivations, 0)
        XCTAssertEqual(summary.maxPreviewHostConcurrentSampleBufferHosts, 3)
        XCTAssertEqual(summary.maxPreviewHostSuspendedHostCount, 1)
        XCTAssertEqual(summary.maxPreviewHostActiveLeaseCount, 2)
        XCTAssertEqual(summary.maxPreviewHostPooledLayerCount, 1)
        XCTAssertEqual(summary.totalPreviewHostPoolReuses, 1)
    }
}

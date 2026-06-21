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
}

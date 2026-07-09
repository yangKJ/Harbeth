import XCTest
import Metal
import CoreGraphics
import CoreVideo
import CoreMedia
import ImageIO
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif
@testable import Harbeth

final class PluginTests: XCTestCase {

    func testPluginDefaultCapabilityIsNativeMetal() {
        let plugin = MockFilterPlugin(output: .filters([]))

        XCTAssertEqual(plugin.capability, .nativeMetal)
        XCTAssertEqual(plugin.capability.kind, .nativeMetal)
        XCTAssertFalse(plugin.capability.usesCPU)
        XCTAssertFalse(plugin.capability.requiresReadback)
        XCTAssertTrue(plugin.capability.cacheable)
        XCTAssertTrue(plugin.capability.supportsLowLatencyFrameFlow)
    }

    func testPluginContextPathReceivesCustomCapability() throws {
        let input = try makeTexture(pixel: [90, 120, 180, 255])
        let plugin = ContextCapturingPlugin(
            output: .filters([C7Brightness(brightness: 0.05)]),
            capability: .cpu
        )
        let direct = try ImageNode
            .source(.texture(input))
            .applying(pluginOutput: plugin.output)
            .makeTexture(profile: .stablePreview)
        let bridged = try ImageNode
            .source(.texture(input))
            .applying(plugin: plugin, profile: .readbackQuality)
            .makeTexture(profile: .stablePreview)

        XCTAssertEqual(try firstPixel(in: direct), try firstPixel(in: bridged))
        XCTAssertEqual(plugin.capturedContext?.profile, .readbackQuality)
        XCTAssertEqual(plugin.capturedContext?.identifier, plugin.pluginIdentifier)
        XCTAssertEqual(plugin.capturedContext?.metadata["pluginIdentifier"], plugin.pluginIdentifier)
        XCTAssertEqual(plugin.capturedContext?.metadata["pluginBoundaryKind"], PluginBoundaryKind.cpu.rawValue)
        XCTAssertTrue(plugin.capability.usesCPU)
        XCTAssertTrue(plugin.capability.requiresReadback)
        XCTAssertFalse(plugin.capability.supportsLowLatencyFrameFlow)
    }

    func testPluginSourceOutputsPreserveSourceDescriptors() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [120, 80, 40, 255])
        let image = try XCTUnwrap(input.c7.toImage())
        let cgImage = try XCTUnwrap(image.c7.toCGImage())
        let pixelBuffer = try XCTUnwrap(cgImage.c7.toPixelBuffer())
        let sampleBuffer = try XCTUnwrap(pixelBuffer.c7.toCMSampleBuffer())

        let cases: [(PluginOutput, String)] = [
            (.texture(input), "texture"),
            (.image(image), "image"),
            (.cgImage(cgImage), "cgImage"),
            (.pixelBuffer(pixelBuffer), "pixelBuffer"),
            (.sampleBuffer(sampleBuffer), "sampleBuffer")
        ]

        for (output, expectedKind) in cases {
            let descriptor = try output.sourceDescriptor()
            let node = ImageNode.source(try output.makeImageSource())
            let request = try node.makeRenderRequest(profile: .stablePreview)
            let previewFrame = try output.makePreviewFrame(profile: .stablePreview)

            XCTAssertEqual(descriptor.kind, expectedKind)
            XCTAssertEqual(request.source.kind, expectedKind)
            XCTAssertEqual(previewFrame.sourceDescriptor.kind, expectedKind)
            XCTAssertEqual(previewFrame.profile, .stablePreview)
        }
    }

    func testImageNodeApplyingPluginOutputFiltersMatchesDirectRoute() throws {
        let input = try makeTexture(pixel: [120, 80, 40, 255])
        let direct = try ImageNode
            .source(.texture(input))
            .applying(filters: [
                C7Brightness(brightness: 0.12),
                C7Contrast(contrast: 1.08)
            ])
            .makeTexture(profile: .stablePreview)
        let pluginOutput = PluginOutput.filters([
            C7Brightness(brightness: 0.12),
            C7Contrast(contrast: 1.08)
        ])
        let bridged = try ImageNode
            .source(.texture(input))
            .applying(pluginOutput: pluginOutput)
            .makeTexture(profile: .stablePreview)

        XCTAssertEqual(try firstPixel(in: direct), try firstPixel(in: bridged))
    }

    func testImageNodeApplyingFilterPluginMatchesDirectRoute() throws {
        let input = try makeTexture(pixel: [90, 120, 180, 255])
        let plugin = MockFilterPlugin(
            output: .filters([
                C7Brightness(brightness: 0.08),
                C7Saturation(saturation: 1.1)
            ])
        )
        let direct = try ImageNode
            .source(.texture(input))
            .applying(filters: [
                C7Brightness(brightness: 0.08),
                C7Saturation(saturation: 1.1)
            ])
            .makeTexture(profile: .stablePreview)
        let bridged = try ImageNode
            .source(.texture(input))
            .applying(plugin: plugin)
            .makeTexture(profile: .stablePreview)

        XCTAssertEqual(try firstPixel(in: direct), try firstPixel(in: bridged))
    }

    func testImageNodeApplyingEditRecipeOutputMatchesDirectRoute() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(
                targetSize: CGSize(width: 2, height: 2),
                aspectPolicy: .fit
            )
        )
        let direct = try ImageNode
            .source(.texture(input))
            .editing(recipe)
            .makeTexture(profile: .stablePreview)
        let bridged = try ImageNode
            .source(.texture(input))
            .applying(pluginOutput: .editRecipe(recipe))
            .makeTexture(profile: .stablePreview)

        XCTAssertEqual(direct.width, bridged.width)
        XCTAssertEqual(direct.height, bridged.height)
        XCTAssertEqual(try firstPixel(in: direct), try firstPixel(in: bridged))
    }

    func testImageNodeApplyingLayerCompositeOutputMatchesDirectRoute() throws {
        let background = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))]
        )
        let direct = try ImageNode.layerComposite(recipe)
            .makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        let bridged = try ImageNode
            .source(.texture(background))
            .applying(pluginOutput: .layerComposite(recipe))
            .makeTexture(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(try firstPixel(in: direct), try firstPixel(in: bridged))
    }

    func testImageNodeApplyingLocalEffectOutputMatchesDirectRoute() throws {
        let input = try makeTexture(pixel: [100, 100, 100, 255])
        let maskTexture = try makeTexture(pixel: [255, 255, 255, 255])
        let localEffect = LocalEffectRecipe(
            filters: [C7Brightness(brightness: 0.2)],
            mask: MaskDescriptor(texture: maskTexture)
        )

        let direct = try ImageNode
            .source(.texture(input))
            .editing(EditRecipe(localEffects: [localEffect]))
            .makeTexture(profile: .stablePreview)
        let bridged = try ImageNode
            .source(.texture(input))
            .applying(pluginOutput: .localEffect(localEffect))
            .makeTexture(profile: .stablePreview)

        XCTAssertEqual(try firstPixel(in: direct), try firstPixel(in: bridged))
    }

    func testImageNodePreviewFrameMatchesRenderedFrameContract() throws {
        let input = try makeTexture(pixel: [140, 100, 60, 255])
        let frame = try ImageNode
            .source(.texture(input))
            .applying(C7Brightness(brightness: 0.1))
            .makeFrame(profile: .stablePreview)

        XCTAssertTrue(frame.texture.width > 0)
        XCTAssertEqual(frame.sourceDescriptor.kind, "texture")
        XCTAssertEqual(frame.profile, .stablePreview)
        XCTAssertEqual(frame.renderIntent, .stable)
    }

    #if canImport(UIKit) && !os(watchOS)
    func testRenderViewDisplayUpdatesRenderedFrameWithoutLosingTextureCompatibility() throws {
        let pixelBuffer = try makePixelBuffer(width: 256, height: 128)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        CMSetAttachment(
            sampleBuffer,
            key: kCGImagePropertyOrientation,
            value: NSNumber(value: CGImagePropertyOrientation.right.rawValue),
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )
        CMSetAttachment(
            sampleBuffer,
            key: harbethFrameMirrorHorizontallyAttachmentKey,
            value: kCFBooleanTrue,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )
        CMSetAttachment(
            sampleBuffer,
            key: harbethFrameFollowsDeviceOrientationAttachmentKey,
            value: kCFBooleanTrue,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )
        let previewFrame = try HarbethIO(element: sampleBuffer, filters: [])
            .renderFrame(profile: .interactiveLatency)
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 32), device: MTLCreateSystemDefaultDevice())
        view.preferredDrawableScale = 1

        view.layoutSubviews()
        view.display(previewFrame)

        XCTAssertTrue(view.texture === previewFrame.texture)
        XCTAssertEqual(view.currentRenderedFrame?.sourceDescriptor.kind, "sampleBuffer")
        XCTAssertTrue(view.isRealtimePreviewFriendly)
        XCTAssertTrue(view.supportsVisibilityPauseForCurrentFrame)
        XCTAssertTrue(view.hasCompleteRealtimePreviewMetadata)
        XCTAssertEqual(view.currentPreviewHostStrategy, PreviewHostStrategy.sampleBufferPassthroughHost.rawValue)
        XCTAssertTrue(view.isUsingSampleBufferPreviewHost)
        XCTAssertTrue(view.isPaused)
        XCTAssertTrue(view.enableSetNeedsDisplay)
        XCTAssertEqual(view.drawableSize.width, 64)
        XCTAssertEqual(view.drawableSize.height, 32)

        let replacement = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        view.texture = replacement

        XCTAssertTrue(view.texture === replacement)
        XCTAssertNil(view.currentRenderedFrame)
        XCTAssertFalse(view.isUsingSampleBufferPreviewHost)
        XCTAssertEqual(view.currentPreviewHostStrategy, PreviewHostStrategy.metalTextureHost.rawValue)
    }

    func testRenderViewFallsBackToMetalStateWhenDisplayingNonSampleBufferFrame() throws {
        let pixelBuffer = try makePixelBuffer(width: 64, height: 64)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        let sampleFrame = try HarbethIO(element: sampleBuffer, filters: [])
            .renderFrame(profile: .interactiveLatency)
        let texture = try makeTexture(width: 64, height: 64, pixel: [200, 50, 20, 255])
        let textureFrame = try HarbethIO(element: texture, filters: [])
            .renderFrame(profile: .stablePreview)
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())

        view.layoutSubviews()
        view.display(sampleFrame)
        XCTAssertTrue(view.isUsingSampleBufferPreviewHost)

        view.display(textureFrame)

        XCTAssertFalse(view.isUsingSampleBufferPreviewHost)
        XCTAssertEqual(view.currentPreviewHostStrategy, PreviewHostStrategy.metalTextureHost.rawValue)
        XCTAssertFalse(view.hostFellBackCurrentFrameToMetal)
    }

    func testRenderViewExecutionReportDoesNotRewriteStaticRequestDiagnostics() throws {
        PreviewHostFleetRegistry.resetForTesting()
        PreviewHostRuntimeSummaryCache.resetForTesting()
        let pixelBuffer = try makePixelBuffer(width: 64, height: 64)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        let node = ImageNode.sampleBuffer(sampleBuffer).applying(C7Brightness(brightness: 0.1))
        let request = try node.makeRenderRequest(profile: .stablePreview)
        let expectedStrategy = request.diagnostics.resolvedPreviewHostStrategy
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())

        view.layoutSubviews()
        view.display(try node.makeFrame(profile: .stablePreview))
        view.debugSimulatePreviewHostFallbackForTesting()

        XCTAssertEqual(request.diagnostics.resolvedPreviewHostStrategy, expectedStrategy)
        XCTAssertEqual(request.diagnostics.hostFellBackToMetal, false)
        XCTAssertEqual(view.currentPreviewHostExecutionReport.predictedStrategy, expectedStrategy)
        XCTAssertEqual(view.currentPreviewHostExecutionReport.actualResolvedHostStrategy, PreviewHostStrategy.metalTextureHost.rawValue)
        XCTAssertEqual(view.currentPreviewHostExecutionReport.state, PreviewHostExecutionState.fallbackMetal.rawValue)
        XCTAssertTrue(view.hostFellBackCurrentFrameToMetal)
    }

    func testRenderViewSampleBufferHostPoolCoordinatesMultipleViews() throws {
        SampleBufferPreviewLayerPool.resetForTesting()
        PreviewHostFleetRegistry.resetForTesting()
        PreviewHostRuntimeSummaryCache.resetForTesting()
        let pixelBuffer = try makePixelBuffer(width: 64, height: 64)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        let frame = try HarbethIO(element: sampleBuffer, filters: [])
            .renderFrame(profile: .interactiveLatency)
        let first = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())
        let second = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())

        first.layoutSubviews()
        second.layoutSubviews()
        first.display(frame)
        second.display(frame)

        let activeSnapshot = SampleBufferPreviewLayerPool.snapshot()
        let activeFleet = PreviewHostFleetRegistry.snapshot()
        XCTAssertEqual(activeSnapshot.activeLeaseCount, 2)
        XCTAssertEqual(activeSnapshot.totalTakeCount, 2)
        XCTAssertEqual(activeSnapshot.totalReturnCount, 0)
        XCTAssertEqual(activeFleet.activeSampleBufferHostCount, 2)
        XCTAssertEqual(activeFleet.maxConcurrentSampleBufferHosts, 2)

        first.display(nil)
        second.display(nil)

        let returnedSnapshot = SampleBufferPreviewLayerPool.snapshot()
        let returnedFleet = PreviewHostFleetRegistry.snapshot()
        XCTAssertEqual(returnedSnapshot.activeLeaseCount, 0)
        XCTAssertEqual(returnedSnapshot.totalReturnCount, 2)
        XCTAssertGreaterThanOrEqual(returnedSnapshot.pooledLayerCount, 2)
        XCTAssertEqual(returnedFleet.activeHostCount, 0)

        let reused = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())
        reused.layoutSubviews()
        reused.display(frame)

        let reusedSnapshot = SampleBufferPreviewLayerPool.snapshot()
        let reusedFleet = PreviewHostFleetRegistry.snapshot()
        XCTAssertGreaterThanOrEqual(reusedSnapshot.totalReuseCount, 1)
        XCTAssertEqual(reusedSnapshot.activeLeaseCount, 1)
        XCTAssertEqual(reusedFleet.activeSampleBufferHostCount, 1)

        reused.display(nil)
        SampleBufferPreviewLayerPool.resetForTesting()
        PreviewHostFleetRegistry.resetForTesting()
    }

    func testRenderViewSampleBufferHostSuspendsAndResumesForApplicationLifecycle() throws {
        SampleBufferPreviewLayerPool.resetForTesting()
        PreviewHostFleetRegistry.resetForTesting()
        PreviewHostRuntimeSummaryCache.resetForTesting()
        let pixelBuffer = try makePixelBuffer(width: 64, height: 64)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        let frame = try HarbethIO(element: sampleBuffer, filters: [])
            .renderFrame(profile: .interactiveLatency)
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())

        view.layoutSubviews()
        view.display(frame)
        let initialEnqueueCount = view.currentPreviewHostEnqueueCount

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(view.currentPreviewHostSuspensionReason, PreviewHostSuspensionReason.applicationInactive.rawValue)
        XCTAssertEqual(view.currentPreviewHostLifecyclePauseCount, 1)
        XCTAssertEqual(view.currentPreviewHostVisibilityPauseCount, 0)
        XCTAssertEqual(view.currentPreviewHostExecutionReport.state, PreviewHostExecutionState.suspended.rawValue)

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertNil(view.currentPreviewHostSuspensionReason)
        XCTAssertEqual(view.currentPreviewHostLifecycleResumeCount, 1)
        XCTAssertGreaterThan(view.currentPreviewHostEnqueueCount, initialEnqueueCount)
        XCTAssertEqual(view.currentPreviewHostExecutionReport.state, PreviewHostExecutionState.sampleBufferActive.rawValue)

        let snapshot = SampleBufferPreviewLayerPool.snapshot()
        let fleet = PreviewHostFleetRegistry.snapshot()
        XCTAssertGreaterThanOrEqual(snapshot.totalLifecyclePauseCount, 1)
        XCTAssertGreaterThanOrEqual(snapshot.totalLifecycleResumeCount, 1)
        XCTAssertGreaterThanOrEqual(fleet.totalLifecycleSuspensionCount, 1)

        view.display(nil)
        SampleBufferPreviewLayerPool.resetForTesting()
        PreviewHostFleetRegistry.resetForTesting()
    }

    func testRenderViewRuntimePreviewHostSummaryBridgesExecutionAndFleetState() throws {
        PreviewHostFleetRegistry.resetForTesting()
        PreviewHostRuntimeSummaryCache.resetForTesting()
        let pixelBuffer = try makePixelBuffer(width: 64, height: 64)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        let frame = try HarbethIO(element: sampleBuffer, filters: [])
            .renderFrame(profile: .interactiveLatency)
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())

        view.layoutSubviews()
        view.display(frame)
        view.debugSimulatePreviewHostRecoveryForTesting()

        let summary = view.makeCurrentRuntimePreviewHostSummary()

        XCTAssertEqual(summary.predictedStrategy, PreviewHostStrategy.sampleBufferPassthroughHost.rawValue)
        XCTAssertEqual(summary.actualBackingKind, PreviewHostBackingKind.sampleBufferDisplayLayer.rawValue)
        XCTAssertEqual(summary.state, PreviewHostExecutionState.recovering.rawValue)
        XCTAssertEqual(summary.recoveryCount, 1)
        XCTAssertGreaterThanOrEqual(summary.fleetActiveSampleBufferHostCount, 1)

        view.display(nil)
        PreviewHostFleetRegistry.resetForTesting()
    }

    func testRenderViewPreferredDrawableScaleControlsDrawableSize() {
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 48, height: 24), device: MTLCreateSystemDefaultDevice())
        view.preferredDrawableScale = 2

        view.layoutSubviews()

        XCTAssertEqual(view.drawableSize.width, 96)
        XCTAssertEqual(view.drawableSize.height, 48)
    }
    #endif

    private func makeTexture(width: Int = 1, height: Int = 1, pixel: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        var bytes = [UInt8]()
        for _ in 0..<(width * height) {
            bytes.append(contentsOf: pixel)
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func makePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer),
            kCVReturnSuccess
        )
        return try XCTUnwrap(pixelBuffer)
    }

    private func firstPixel(in texture: MTLTexture) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: 4,
            from: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0
        )
        return bytes
    }
}

#if canImport(AppKit) && !os(watchOS)
extension PluginTests {
    func testRenderGraphDebugSnapshotIncludesRuntimePreviewHostSummaryAfterDisplay() throws {
        PreviewHostFleetRegistry.resetForTesting()
        PreviewHostRuntimeSummaryCache.resetForTesting()
        let pixelBuffer = try makePixelBuffer(width: 64, height: 64)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        let node = ImageNode.sampleBuffer(sampleBuffer).applying(C7Brightness(brightness: 0.1))
        let preflightSnapshot = try node.makeDebugSnapshot(profile: .interactiveLatency)
        XCTAssertNil(preflightSnapshot.diagnostics.runtimePreviewHostSummary)

        let frame = try node.makeFrame(profile: .interactiveLatency)
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())
        view.layout()
        view.display(frame)

        let runtimeSnapshot = try node.makeDebugSnapshot(profile: .interactiveLatency)
        let summary = try XCTUnwrap(runtimeSnapshot.diagnostics.runtimePreviewHostSummary)

        XCTAssertEqual(summary.predictedStrategy, view.currentPreviewHostExecutionReport.predictedStrategy)
        XCTAssertEqual(summary.actualBackingKind, view.currentPreviewHostExecutionReport.actualBackingKind)
        XCTAssertEqual(summary.actualResolvedHostStrategy, view.currentPreviewHostExecutionReport.actualResolvedHostStrategy)
        XCTAssertEqual(summary.state, view.currentPreviewHostExecutionReport.state)
        XCTAssertEqual(summary.fleetActiveHostCount, view.currentPreviewHostFleetSnapshot.activeHostCount)

        view.display(nil)
        PreviewHostFleetRegistry.resetForTesting()
    }

    func testRenderGraphDebugSnapshotMarksRuntimePredictionDriftAfterFallback() throws {
        PreviewHostFleetRegistry.resetForTesting()
        PreviewHostRuntimeSummaryCache.resetForTesting()
        let pixelBuffer = try makePixelBuffer(width: 64, height: 64)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        let frame = try HarbethIO(element: sampleBuffer, filters: [])
            .renderFrame(profile: .interactiveLatency)
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: MTLCreateSystemDefaultDevice())

        view.layout()
        view.display(frame)
        view.debugSimulatePreviewHostFallbackForTesting()

        let summary = try XCTUnwrap(
            try ImageNode.sampleBuffer(sampleBuffer)
                .makeDebugSnapshot(profile: .interactiveLatency)
                .diagnostics.runtimePreviewHostSummary
        )

        XCTAssertTrue(summary.predictionDrifted)
        XCTAssertEqual(summary.predictionDriftReason, "strategyMismatch")
        XCTAssertEqual(summary.actualResolvedHostStrategy, PreviewHostStrategy.metalTextureHost.rawValue)
        XCTAssertTrue(summary.fellBackToMetal)

        view.display(nil)
        PreviewHostFleetRegistry.resetForTesting()
    }
}
#endif

private struct MockFilterPlugin: FilterPlugin {
    let output: PluginOutput

    var pluginIdentifier: String {
        "mock.filter"
    }

    func makeOutput(frame: RenderedFrame) throws -> PluginOutput {
        output
    }
}

private final class ContextCapturingPlugin: FilterPlugin {
    let output: PluginOutput
    let capability: PluginCapability
    private(set) var capturedContext: PluginContext?

    init(output: PluginOutput, capability: PluginCapability) {
        self.output = output
        self.capability = capability
    }

    var pluginIdentifier: String {
        "mock.context"
    }

    func makeOutput(frame: RenderedFrame) throws -> PluginOutput {
        output
    }

    func makeOutput(frame: RenderedFrame, context: PluginContext) throws -> PluginOutput {
        capturedContext = context
        return output
    }
}

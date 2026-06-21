import XCTest
import Metal
@testable import Harbeth

final class RenderedFrameTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Shared.shared.deinitDevice()
    }

    func testRenderFrameFromTextureCarriesMetadata() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 4, height: 3, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests")

        let frame = try HarbethIO(element: texture, filters: [])
            .renderFrame(profile: .stablePreview, metadata: ["purpose": "unit"])

        XCTAssertTrue(frame.texture === texture)
        XCTAssertEqual(frame.size.width, 4)
        XCTAssertEqual(frame.size.height, 3)
        XCTAssertEqual(frame.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(frame.profile, .stablePreview)
        XCTAssertEqual(frame.renderIntent, .stable)
        XCTAssertEqual(frame.sourceTier, .original)
        XCTAssertEqual(frame.orientation, .up)
        XCTAssertEqual(frame.sourceDescriptor.kind, "texture")
        XCTAssertEqual(frame.sourceDescriptor.sourceTier, .original)
        XCTAssertEqual(frame.semantic.role, .derivative)
        XCTAssertEqual(frame.semantic.purpose, .stable)
        XCTAssertEqual(frame.semantic.fidelity, .displayOptimized)
        XCTAssertEqual(frame.metadata["purpose"], "unit")
        XCTAssertEqual(frame.metadata["filterChainFingerprint"], "")
        XCTAssertEqual(frame.cacheIdentity.renderIntent, .stable)
        XCTAssertTrue(frame.cacheIdentity.fingerprint.contains("kind=texture"))
        XCTAssertNil(frame.lease, "直接复用调用方输入纹理时不应伪造 lease。")
        XCTAssertFalse(frame.identifier.isEmpty)
        XCTAssertGreaterThan(frame.generation, 0)
        XCTAssertEqual(frame.token.identifier, frame.identifier)
        XCTAssertEqual(frame.token.generation, frame.generation)
    }

    func testFrameRendererGenerationIncreases() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "RenderedFrameTests")
        let renderer = FrameRenderer(source: .texture(texture), profile: .responseLatency, identifier: "frame-generation")

        let first = try renderer.renderFrame()
        let second = try renderer.renderFrame()

        XCTAssertEqual(first.identifier, "frame-generation")
        XCTAssertEqual(second.identifier, "frame-generation")
        XCTAssertGreaterThan(second.generation, first.generation)
        XCTAssertEqual(first.profile, .responseLatency)
        XCTAssertEqual(first.renderIntent, .responsive)
        XCTAssertEqual(first.replayBaseContract.preferredSourceTier, .stableReusable)
    }

    func testFrameRenderTokenIsAssignedBeforeAsyncCompletion() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "RenderedFrameTests")
        let renderer = FrameRenderer(source: .texture(texture), profile: .interactiveLatency, identifier: "async-token")

        let firstToken = renderer.makeToken()
        let secondToken = renderer.makeToken()

        XCTAssertEqual(firstToken.identifier, "async-token")
        XCTAssertEqual(secondToken.identifier, "async-token")
        XCTAssertTrue(firstToken.isOlder(than: secondToken))
    }

    func testFrameRendererUsesCallerProvidedToken() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "RenderedFrameTests")
        let renderer = FrameRenderer(source: .texture(texture), profile: .stablePreview, identifier: "manual-token")
        let token = renderer.makeToken()
        let frame = try renderer.renderFrame(token: token)

        XCTAssertEqual(frame.token, token)
        XCTAssertEqual(frame.identifier, token.identifier)
        XCTAssertEqual(frame.generation, token.generation)
    }

    func testHarbethIOUsesCallerProvidedFrameToken() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "RenderedFrameTests")
        let io = HarbethIO(element: texture, filters: [])
        let token = io.makeFrameRenderToken()
        let frame = try io.renderFrame(profile: .responseLatency, token: token)

        XCTAssertEqual(frame.token, token)
        XCTAssertEqual(frame.profile, .responseLatency)
    }

    func testRenderedFrameCanRejectStaleTokenForSameIdentifier() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "RenderedFrameTests")
        let older = FrameRenderToken(identifier: "stable-frame", generation: 1)
        let newer = FrameRenderToken(identifier: "stable-frame", generation: 2)
        let unrelated = FrameRenderToken(identifier: "thumbnail", generation: 100)
        let frame = RenderedFrame(
            texture: texture,
            profile: .interactiveLatency,
            token: older
        )

        XCTAssertFalse(frame.isCurrent(comparedTo: newer))
        XCTAssertTrue(frame.isCurrent(comparedTo: older))
        XCTAssertTrue(frame.isCurrent(comparedTo: unrelated))
    }

    func testRenderProfileSemanticFlags() {
        XCTAssertTrue(RenderProfile.interactiveLatency.usesRealTimeCommit)
        XCTAssertFalse(RenderProfile.interactiveLatency.enablesDoubleBuffer)
        XCTAssertFalse(RenderProfile.interactiveLatency.createsDestinationTexture)
        XCTAssertFalse(RenderProfile.interactiveLatency.requiresCompletedGPUWorkBeforeReadback)

        XCTAssertFalse(RenderProfile.responseLatency.usesRealTimeCommit)
        XCTAssertTrue(RenderProfile.responseLatency.enablesDoubleBuffer)
        XCTAssertTrue(RenderProfile.stablePreview.createsDestinationTexture)
        XCTAssertTrue(RenderProfile.exportQuality.requiresCompletedGPUWorkBeforeReadback)
        XCTAssertTrue(RenderProfile.readbackQuality.requiresCompletedGPUWorkBeforeReadback)

        XCTAssertEqual(RenderProfile.interactiveLatency.defaultRenderIntent, .interactive)
        XCTAssertEqual(RenderProfile.stablePreview.defaultRenderIntent, .stable)
        XCTAssertEqual(RenderProfile.exportQuality.defaultRenderIntent, .export)
        XCTAssertEqual(RenderProfile.interactiveLatency.defaultImageSemantic.purpose, .interactive)
        XCTAssertEqual(RenderProfile.interactiveLatency.defaultImageSemantic.fidelity, .lowLatency)
        XCTAssertEqual(RenderProfile.exportQuality.defaultImageSemantic.role, .output)
        XCTAssertEqual(RenderProfile.exportQuality.defaultImageSemantic.purpose, .export)
    }

    func testCopyTextureDoesNotReturnTextureToPoolBeforeCallerReleasesIt() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let source = try TextureLoader.makeTexture(width: 8, height: 8, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "copy-source")
        let copied = try TextureLoader.copyTexture(with: source, identifier: "copy-dest")

        let dequeued = Shared.shared.defaultTexturePool.dequeueTexture(width: copied.width, height: copied.height, pixelFormat: copied.pixelFormat)

        XCTAssertFalse(copied === source)
        XCTAssertNil(dequeued, "A texture returned to the caller must not be immediately available for reuse from the pool.")
    }

    func testTextureLoaderUsesExactPoolSizeByDefault() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let pooled = try TextureLoader.makeTexture(width: 12, height: 12, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "pool-exact-source")
        Shared.shared.defaultTexturePool.enqueueTextureSync(pooled)

        let exact = try TextureLoader.makeTexture(width: 10, height: 10, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "pool-exact-request")

        XCTAssertEqual(exact.width, 10)
        XCTAssertEqual(exact.height, 10)
    }

    func testTextureLoaderCanOptIntoTolerancePoolReuse() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let pooled = try TextureLoader.makeTexture(width: 12, height: 12, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "pool-tolerance-source")
        Shared.shared.defaultTexturePool.enqueueTextureSync(pooled)

        let tolerant = try TextureLoader.makeTexture(width: 10, height: 10, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureAllowsSizeTolerance: true
        ], identifier: "pool-tolerance-request")

        XCTAssertEqual(tolerant.width, 12)
        XCTAssertEqual(tolerant.height, 12)
    }

    func testTextureLeaseReturnsTextureToPoolOnRelease() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let lease = try TextureLoader.makeTextureLease(width: 16, height: 16, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "lease-return")
        let texture = lease.texture

        XCTAssertNil(Shared.shared.defaultTexturePool.dequeueExactTexture(width: 16, height: 16, pixelFormat: .rgba8Unorm))

        lease.release()

        let reused = Shared.shared.defaultTexturePool.dequeueExactTexture(width: 16, height: 16, pixelFormat: .rgba8Unorm)
        XCTAssertTrue(reused === texture)
    }

    func testFilteredFrameCarriesManagedLeaseForFinalTexture() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let texture = try TextureLoader.makeTexture(width: 8, height: 8, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "managed-frame-source")

        let io = HarbethIO(element: texture, filters: [C7Brightness(brightness: 0.1)])
        let frame = try io.renderFrame(profile: .stablePreview, metadata: ["case": "managed-output"])

        XCTAssertNotNil(frame.lease)
        XCTAssertTrue(frame.lease?.texture === frame.texture)
        XCTAssertEqual(frame.metadata["case"], "managed-output")
    }

    func testFrameRendererCanApplyDerivativeResizePolicy() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let texture = try TextureLoader.makeTexture(width: 8, height: 6, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "derivative-frame-source")

        let derivative = ImageDerivativeSpec(
            name: "panelThumbnail",
            renderIntent: .delivery,
            sourceTier: .thumbnail,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .thumbnail, fidelity: .thumbnailOptimized),
            outputSizePolicy: .fit(C7Size(width: 4, height: 4))
        )

        let frame = try FrameRenderer(
            source: .texture(texture),
            filters: [],
            profile: .stablePreview,
            renderIntent: derivative.renderIntent,
            identifier: "derivative-frame",
            outputSemantic: derivative.semantic,
            outputDerivative: derivative
        ).renderFrame()

        XCTAssertEqual(frame.derivative.name, "panelThumbnail")
        XCTAssertEqual(frame.resolvedOutputSize, C7Size(width: 4, height: 3))
        XCTAssertEqual(frame.size.width, 4)
        XCTAssertEqual(frame.size.height, 3)
    }

    func testRecipeDrivenFrameCarriesPredictableFilterFingerprint() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let texture = try TextureLoader.makeTexture(width: 4, height: 4, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "recipe-frame-source")
        let recipe = EditRecipe(
            filters: [C7Brightness(brightness: 0.1)],
            localEffects: [
                LocalEffectRecipe(
                    filters: [C7Contrast(contrast: 1.1)],
                    mask: MaskDescriptor(texture: texture, opacity: 1)
                )
            ]
        )

        let frame = try HarbethIO(element: texture, filters: [])
            .renderFrame(recipe: recipe, mode: .preview)

        let fingerprint = frame.metadata["filterChainFingerprint"] ?? ""
        XCTAssertFalse(fingerprint.isEmpty)
        XCTAssertTrue(fingerprint.contains("C7Brightness"))
        XCTAssertTrue(fingerprint.contains("C7MaskRegionBlend"))
    }

    func testTransitionFrameCarriesPredictableFilterFingerprint() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()

        let from = try TextureLoader.makeTexture(width: 4, height: 4, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "transition-from")
        let to = try TextureLoader.makeTexture(width: 4, height: 4, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "transition-to")
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )

        let frame = try HarbethIO(element: from, filters: [])
            .renderTransitionFrame(recipe)

        let fingerprint = frame.metadata["filterChainFingerprint"] ?? ""
        XCTAssertFalse(fingerprint.isEmpty)
        XCTAssertTrue(fingerprint.contains("C7DissolveTransition"))
    }

    func testSourceDescriptorCarriesStableSemanticFingerprint() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 4, height: 4, identifier: "RenderedFrameTests")
        let descriptor = HarbethSource.texture(texture).descriptor

        XCTAssertEqual(descriptor.semantic, .sourceOriginal)
        XCTAssertEqual(descriptor.sourceTier, .original)
        XCTAssertTrue(descriptor.fingerprint.contains("role=source"))
        XCTAssertTrue(descriptor.fingerprint.contains("tier=original"))
        XCTAssertTrue(descriptor.fingerprint.contains("purpose=processingInput"))
        XCTAssertTrue(descriptor.fingerprint.contains("fidelity=original"))
    }
}

import XCTest
import Metal
import CoreVideo
import CoreMedia
import ImageIO
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
        XCTAssertEqual(frame.frameHostSourceDescriptor.frameSize, C7Size(width: 4, height: 3))
        XCTAssertEqual(frame.frameHostRuntimeHint.timingPolicy, .displayStable)
        XCTAssertTrue(frame.frameHostRuntimeHint.isRealtimePreviewEligible)
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
        XCTAssertEqual(frame.frameHostRuntimeHint.timingPolicy, .lowLatency)
    }

    func testHarbethIOAttachmentDebugPoliciesExposeAuxiliaryHints() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "RenderedFrameTests")
        let node = ImageNode.filters(input: .texture(texture), filters: [RenderAuxiliaryLuminance()])

        let policies = try node.makeAttachmentDebugPolicies()

        XCTAssertEqual(policies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(policies.map(\.interpretation), [.color, .monochrome])
        XCTAssertEqual(policies.map { $0.preferredReadbackPixelFormat }, [.rgba8Unorm, .rgba8Unorm])
    }

    func testRenderedAttachmentSetExposesPrimaryAttachmentBySemantic() throws {
        let contract = RenderOutputContract(
            alpha: .premultiplied,
            colorSpace: .sRGB,
            pixelFormat: .rgba8Unorm,
            additionalAttachments: [.analysis(index: 1, pixelFormat: .rgba8Unorm)]
        )
        let primaryTexture = try TextureLoader.makeTexture(width: 1, height: 1, identifier: "RenderedFrameTests.primaryAttachment")
        let analysisTexture = try TextureLoader.makeTexture(width: 1, height: 1, identifier: "RenderedFrameTests.analysisAttachment")
        let output = RenderedAttachmentSet(
            outputContract: contract,
            attachments: [
                RenderedAttachment(
                    index: 0,
                    semantic: .primaryColor,
                    texture: primaryTexture,
                    debugPolicy: contract.attachments[0].debugPolicy
                ),
                RenderedAttachment(
                    index: 1,
                    semantic: .analysis,
                    texture: analysisTexture,
                    debugPolicy: contract.attachments[1].debugPolicy
                )
            ]
        )

        XCTAssertTrue(output.primary?.texture === primaryTexture)
        XCTAssertTrue(output.attachment(for: .analysis)?.texture === analysisTexture)
        XCTAssertEqual(output.debugPolicies.map(\.label), ["primaryColor", "analysis"])
    }

    func testRenderedAttachmentSetHistogramUsesScalarFieldDefaultChannel() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let contract = RenderOutputContract(
            alpha: .premultiplied,
            colorSpace: .sRGB,
            pixelFormat: .rgba8Unorm,
            additionalAttachments: [.analysis(index: 1, pixelFormat: .rgba8Unorm)]
        )
        let primaryTexture = try TextureLoader.makeTexture(width: 1, height: 1, identifier: "RenderedFrameTests.primaryHistogramAttachment")
        let analysisTexture = try TextureLoader.makeTexture(width: 1, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.analysisHistogramAttachment")
        analysisTexture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: [255, 0, 0, 255],
            bytesPerRow: 4
        )
        let output = RenderedAttachmentSet(
            outputContract: contract,
            attachments: [
                RenderedAttachment(
                    index: 0,
                    semantic: .primaryColor,
                    texture: primaryTexture,
                    debugPolicy: contract.attachments[0].debugPolicy
                ),
                RenderedAttachment(
                    index: 1,
                    semantic: .analysis,
                    texture: analysisTexture,
                    debugPolicy: contract.attachments[1].debugPolicy
                )
            ]
        )

        let histogram = try XCTUnwrap(output.attachment(for: .analysis)?.makeHistogram(bins: 4))
        XCTAssertEqual(histogram.channel, .red)
        XCTAssertEqual(histogram.totalSampleCount, 1)
        XCTAssertEqual(histogram.bins, [0, 0, 0, 1])
    }

    func testRenderedFrameCanMaterializeHistogram() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.frameHistogram")
        seedTexture(texture, width: 2, height: 1, bytes: [
            0, 0, 0, 255,
            255, 255, 255, 255
        ])
        let frame = RenderedFrame(
            texture: texture,
            profile: .readbackQuality,
            token: FrameRenderToken(identifier: "frame-histogram", generation: 1)
        )
        let histogram = try XCTUnwrap(frame.makeHistogram())
        XCTAssertEqual(histogram.channel, .luminance)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.bins[0], 1)
        XCTAssertEqual(histogram.bins[255], 1)
    }

    func testHarbethIORenderHistogramReturnsTextureHistogram() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.ioHistogram")
        seedTexture(texture, width: 2, height: 1, bytes: [
            0, 0, 0, 255,
            255, 255, 255, 255
        ])

        let histogram = try XCTUnwrap(
            HarbethIO(element: texture, filters: [])
                .renderHistogram(channel: .luminance, bins: 256)
        )

        XCTAssertEqual(histogram.channel, .luminance)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.bins[0], 1)
        XCTAssertEqual(histogram.bins[255], 1)
    }

    func testHarbethIORenderHistogramWithGPUMethodReturnsTextureHistogram() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.ioGPUHistogram")
        seedTexture(texture, width: 2, height: 1, bytes: [
            0, 0, 0, 255,
            255, 0, 0, 255
        ])

        let histogram = try XCTUnwrap(
            HarbethIO(element: texture, filters: [])
                .renderHistogram(channel: .red, bins: 4, preferredMethod: .gpuMPS)
        )

        XCTAssertEqual(histogram.channel, .red)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.bins.reduce(0, +), 2)
        XCTAssertEqual(histogram.bins[0], 1)
        XCTAssertEqual(histogram.bins[3], 1)
    }

    func testHarbethIORenderAnalysisBundleSupportsUnifiedAnalysisScope() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.analysisBundle.scope")
        seedTexture(texture, width: 2, height: 1, bytes: [
            0, 0, 0, 255,
            255, 0, 0, 255
        ])
        let mask = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.analysisBundle.scope.mask")
        seedTexture(mask, width: 2, height: 1, bytes: [
            0, 0, 0, 255,
            255, 0, 0, 255
        ])
        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red))

        let bundle = try HarbethIO(element: texture, filters: [])
            .renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )

        XCTAssertEqual(bundle.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
    }

    func testRenderedFrameCanMaterializeColorRangeMaskDescriptor() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 3, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.analysisMask.colorRange")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 3, 1),
            mipmapLevel: 0,
            withBytes: [
                255, 0, 0, 255,
                0, 255, 0, 255,
                255, 255, 255, 255
            ],
            bytesPerRow: 12
        )
        let frame = try HarbethIO(element: texture, filters: []).renderFrame(profile: .readbackQuality)
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let mask = try XCTUnwrap(frame.makeMaskDescriptor(scope: scope))
        let bytes = try XCTUnwrap(mask.texture.c7.bytes())

        XCTAssertEqual(mask.component, .red)
        XCTAssertEqual(bytes.count, 12)
        XCTAssertEqual(Array(bytes[0..<4]), [255, 255, 255, 255])
        XCTAssertEqual(Array(bytes[4..<8]), [0, 0, 0, 255])
        XCTAssertEqual(Array(bytes[8..<12]), [0, 0, 0, 255])
    }

    func testHarbethIORenderHistogramAttachmentWithGPUMethodReturnsPreviewTexture() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.ioGPUHistogramAttachment")
        seedTexture(texture, width: 2, height: 1, bytes: [
            0, 0, 0, 255,
            255, 0, 0, 255
        ])

        let output = try XCTUnwrap(
            HarbethIO(element: texture, filters: []).renderHistogramAttachment(
                channel: .red,
                bins: 4,
                height: 16,
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(output.histogram.channel, .red)
        XCTAssertEqual(output.attachment.semantic, .histogram)
        XCTAssertEqual(output.attachment.pixelFormat, .rgba8Unorm)
        XCTAssertNotNil(output.makeCGImage(colorSpace: CGColorSpaceCreateDeviceRGB()))
    }

    func testHarbethIORenderAnalysisBundleReturnsFrameHistogramAndPreview() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.analysisBundle")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )

        let bundle = try HarbethIO(element: texture, filters: [])
            .renderAnalysisBundle(channel: .red, bins: 4, histogramHeight: 16, preferredMethod: .gpuMPS)

        XCTAssertEqual(bundle.frame.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(bundle.histogram?.channel, .red)
        XCTAssertEqual(bundle.histogram?.bins.reduce(0, +), 2)
        XCTAssertEqual(bundle.statistics?.sampleCount, 2)
        XCTAssertTrue(bundle.analysisScopeFingerprint?.contains("region=none") == true)
        XCTAssertEqual(bundle.histogramAttachment?.attachment.semantic, .histogram)
        XCTAssertEqual(bundle.attachmentDebugPolicies.map(\.label), ["primaryColor"])
        XCTAssertNotNil(bundle.makeHistogramCGImage())
    }


    func testNodeAnalysisBundleCarriesAttachmentPolicies() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 1, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.nodeAnalysisBundle")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: [255, 255, 255, 255],
            bytesPerRow: 4
        )
        let node = ImageNode.filters(input: .texture(texture), filters: [RenderAuxiliaryLuminance()])

        let frame = try node.makeFrame(profile: .readbackQuality)
        let histogramAttachment = frame.renderHistogramAttachment(
            channel: .luminance,
            bins: 16,
            height: 16,
            preferredMethod: .gpuMPS
        )
        let bundle = RenderedAnalysisBundle(
            frame: frame,
            histogram: histogramAttachment?.histogram ?? frame.makeHistogram(channel: .luminance, bins: 16, preferredMethod: .gpuMPS),
            statistics: frame.makeStatistics(),
            colorProbe: frame.makeColorProbe(),
            histogramAttachment: histogramAttachment,
            analysisScopeFingerprint: nil,
            attachmentDebugPolicies: try node.makeAttachmentDebugPolicies(profile: .readbackQuality)
        )

        XCTAssertEqual(bundle.histogram?.channel, .luminance)
        XCTAssertEqual(bundle.attachmentDebugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertNotNil(bundle.histogramAttachment)
    }

    func testHarbethIORenderAttachmentAnalysisBundleReturnsNilForNonRenderChain() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 1, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.noRenderAttachmentAnalysis")

        let bundle = try HarbethIO(element: texture, filters: [C7Brightness(brightness: 0)])
            .renderAttachmentAnalysisBundle()

        XCTAssertNil(bundle)
    }

    func testHarbethIORenderAttachmentSetReturnsNilForNonRenderChain() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 1, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.noRenderAttachmentSet")

        let attachmentSet = try HarbethIO(element: texture, filters: [C7Brightness(brightness: 0)])
            .renderAttachmentSet()

        XCTAssertNil(attachmentSet)
    }

    func testHarbethIORenderAttachmentSetUsesFinalRenderPrimitive() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentSet")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )

        let attachmentSet = try XCTUnwrap(
            HarbethIO(
                element: texture,
                filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()]
            ).renderAttachmentSet()
        )

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(attachmentSet.attachments.count, 2)
        XCTAssertEqual(attachmentSet.primary?.semantic, .primaryColor)
        XCTAssertEqual(attachmentSet.attachment(for: .luminance)?.semantic, .luminance)
        XCTAssertNotNil(attachmentSet.texture(for: .luminance))
    }

    func testHarbethIORenderAttachmentSetForNodeUsesFinalRenderPrimitive() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentSet.node")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let node = ImageNode
            .texture(texture)
            .applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])
            .withCachePolicy(.persistent)

        let attachmentSet = try XCTUnwrap(node.makeAttachmentSet())

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(attachmentSet.attachments.count, 2)
        XCTAssertEqual(attachmentSet.primary?.semantic, .primaryColor)
        XCTAssertEqual(attachmentSet.attachment(for: .luminance)?.semantic, .luminance)
    }

    func testHarbethIORenderAttachmentSetForRecipeUsesFinalRenderPrimitive() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentSet.recipe")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let mask = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentSet.recipe.mask")
        mask.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                255, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let recipe = EditRecipe(localEffects: [
            LocalEffectRecipe(
                filters: [RenderAuxiliaryLuminance()],
                mask: MaskDescriptor(texture: mask, component: .red)
            )
        ])

        let attachmentSet = try XCTUnwrap(
            recipe
                .makeNode(source: .texture(texture))
                .applying(RenderAuxiliaryLuminance())
                .makeAttachmentSet(profile: recipe.contract(for: .preview).profile)
        )

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(attachmentSet.attachments.count, 2)
        XCTAssertEqual(attachmentSet.primary?.semantic, .primaryColor)
        XCTAssertEqual(
            attachmentSet.attachment(for: RenderOutputAttachmentSemantic.luminance)?.semantic,
            RenderOutputAttachmentSemantic.luminance
        )
    }

    func testHarbethIORenderAttachmentSetForCompositeUsesFinalRenderPrimitive() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let background = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentSet.composite.background")
        background.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let layer = try TextureLoader.makeTexture(width: 1, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentSet.composite.layer")
        layer.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: [255, 255, 255, 255],
            bytesPerRow: 4
        )
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(content: .texture(layer))
            ]
        )
        let attachmentSet = try XCTUnwrap(
            recipe
                .makeNode()
                .applying(RenderAuxiliaryLuminance())
                .makeAttachmentSet(profile: recipe.profile)
        )

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(attachmentSet.attachments.count, 2)
        XCTAssertEqual(attachmentSet.primary?.semantic, .primaryColor)
        XCTAssertEqual(attachmentSet.attachment(for: .luminance)?.semantic, .luminance)
    }

    func testHarbethIORenderAttachmentSetForTransitionUsesFinalRenderPrimitive() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let from = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentSet.transition.from")
        let to = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentSet.transition.to")
        from.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        to.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 255, 255,
                255, 255, 255, 255
            ],
            bytesPerRow: 8
        )
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )
        let attachmentSet = try XCTUnwrap(
            recipe
                .makeNode()
                .applying(RenderAuxiliaryLuminance())
                .makeAttachmentSet(profile: recipe.profile)
        )

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(attachmentSet.attachments.count, 2)
        XCTAssertEqual(attachmentSet.primary?.semantic, .primaryColor)
        XCTAssertEqual(
            attachmentSet.attachment(for: RenderOutputAttachmentSemantic.luminance)?.semantic,
            RenderOutputAttachmentSemantic.luminance
        )
    }

    func testHarbethIORenderAttachmentAnalysisBundleUsesFinalRenderPrimitive() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.renderAttachmentAnalysis")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )

        let bundle = try XCTUnwrap(
            HarbethIO(
                element: texture,
                filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()]
            ).renderAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(bundle.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(bundle.analyses.count, 2)
        XCTAssertEqual(bundle.primary?.attachment.semantic, .primaryColor)
        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 2)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.attachment.semantic, .luminance)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.channel, .luminance)
    }

    func testHarbethIORenderAttachmentAnalysisBundleCanRestrictHistogramRegion() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.renderAttachmentAnalysis.region")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )

        let bundle = try XCTUnwrap(
            HarbethIO(
                element: texture,
                filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()]
            ).renderAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                region: MTLRegionMake2D(1, 0, 1, 1),
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.primary?.histogram?.bins.reduce(0, +), 1)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.bins.reduce(0, +), 1)
        XCTAssertNotNil(bundle.primary?.histogramAttachment)
        XCTAssertNotNil(bundle.analysis(for: .luminance)?.histogramAttachment)
    }

    func testHarbethIORenderAttachmentAnalysisBundleCanRestrictHistogramMaskCoverage() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.renderAttachmentAnalysis.mask")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let mask = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.renderAttachmentAnalysis.mask.coverage")
        mask.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                255, 0, 0, 255,
                0, 0, 0, 255
            ],
            bytesPerRow: 8
        )

        let bundle = try XCTUnwrap(
            HarbethIO(
                element: texture,
                filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()]
            ).renderAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                mask: MaskDescriptor(texture: mask, component: .red),
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.primary?.histogram?.bins, [1, 0, 0, 0])
        XCTAssertEqual(bundle.primary?.statistics?.sampleCount, 1)
        XCTAssertEqual(Double(try XCTUnwrap(bundle.primary?.statistics).meanRed), 0, accuracy: 0.0001)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.bins.reduce(0, +), 1)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.statistics?.sampleCount, 1)
        XCTAssertEqual(Double(try XCTUnwrap(bundle.analysis(for: .luminance)?.statistics).meanLuminance), 0, accuracy: 0.0001)
    }

    func testHarbethIORenderAttachmentAnalysisBundleSupportsUnifiedAnalysisScope() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.renderAttachmentAnalysis.scope")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let mask = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.renderAttachmentAnalysis.scope.mask")
        mask.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red))

        let bundle = try XCTUnwrap(
            HarbethIO(
                element: texture,
                filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()]
            ).renderAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertNotNil(bundle.primary?.histogram)
        XCTAssertNotNil(bundle.primary?.statistics)
        XCTAssertNotNil(bundle.analysis(for: .luminance)?.histogram)
        XCTAssertNotNil(bundle.analysis(for: .luminance)?.statistics)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
    }

    func testHarbethIORenderAttachmentSetBridgesNodeFacade() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.nodeAttachmentSetFacade")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let node = ImageNode
            .texture(texture)
            .applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])

        let attachmentSet = try XCTUnwrap(node.makeAttachmentSet())

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(attachmentSet.attachments.count, 2)
    }

    func testHarbethIORenderAttachmentAnalysisBundleBridgesNodeScopeFacade() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.nodeAttachmentAnalysisFacade")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let mask = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite, .renderTarget])
        ], identifier: "RenderedFrameTests.nodeAttachmentAnalysisFacade.mask")
        mask.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: [
                0, 0, 0, 255,
                255, 0, 0, 255
            ],
            bytesPerRow: 8
        )
        let node = ImageNode
            .texture(texture)
            .applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])
        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red))

        let bundle = try XCTUnwrap(node.makeAttachmentAnalysisBundle(
            bins: 4,
            histogramHeight: 16,
            scope: scope,
            preferredMethod: .gpuMPS
        ))

        XCTAssertEqual(bundle.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertNotNil(bundle.primary?.histogram)
        XCTAssertNotNil(bundle.primary?.statistics)
        XCTAssertNotNil(bundle.analysis(for: .luminance)?.histogram)
        XCTAssertNotNil(bundle.analysis(for: .luminance)?.statistics)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
    }


    func testHarbethIORenderHistogramFromCompositePathReturnsTextureHistogram() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let background = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.compositeHistogramBackground")
        seedTexture(background, width: 2, height: 1, bytes: [
            0, 0, 0, 255,
            0, 0, 0, 255
        ])

        let layer = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.compositeHistogramLayer")
        seedTexture(layer, width: 2, height: 1, bytes: [
            255, 0, 0, 255,
            255, 0, 0, 255
        ])

        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer))]
        )

        let histogram = try XCTUnwrap(
            try ImageNode.layerComposite(recipe)
                .makeFrame(profile: recipe.profile, derivative: recipe.derivative)
                .makeHistogram(channel: .red, bins: 4)
        )

        XCTAssertEqual(histogram.channel, .red)
        XCTAssertEqual(histogram.totalSampleCount, 2)
        XCTAssertEqual(histogram.bins, [0, 0, 0, 2])
    }

    func testCompositeAnalysisBundleReturnsHistogramAndPrimaryPolicy() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let background = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.compositeAnalysisBackground")
        seedTexture(background, width: 2, height: 1, bytes: [
            0, 0, 0, 255,
            0, 0, 0, 255
        ])

        let layer = try TextureLoader.makeTexture(width: 2, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.compositeAnalysisLayer")
        seedTexture(layer, width: 2, height: 1, bytes: [
            255, 0, 0, 255,
            255, 0, 0, 255
        ])

        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer))]
        )

        let bundle = try XCTUnwrap(
            try recipe
                .makeNode()
                .makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
                .renderAnalysisBundle(
                    channel: .red,
                    bins: 4,
                    histogramHeight: 16,
                    preferredMethod: .gpuMPS
                )
        )

        XCTAssertEqual(bundle.frame.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(bundle.histogram?.channel, .red)
        XCTAssertEqual(bundle.histogram?.bins, [0, 0, 0, 2])
        XCTAssertEqual(bundle.attachmentDebugPolicies.map(\.label), ["primaryColor"])
        XCTAssertNotNil(bundle.histogramAttachment)
    }


    func testHarbethIORenderHistogramFromNodePathReturnsTextureHistogram() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 1, height: 1, options: [
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm
        ], identifier: "RenderedFrameTests.nodeHistogram")
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: [255, 0, 0, 255],
            bytesPerRow: 4
        )
        let node = ImageNode
            .texture(texture)
            .applying(C7Brightness(brightness: 0))

        let histogram = try XCTUnwrap(node.makeFrame(profile: .readbackQuality).makeHistogram(channel: .red, bins: 4))

        XCTAssertEqual(histogram.channel, .red)
        XCTAssertEqual(histogram.totalSampleCount, 1)
        XCTAssertEqual(histogram.bins, [0, 0, 0, 1])
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
            localEffects: [
                LocalEffectRecipe(
                    filters: [C7Contrast(contrast: 1.1)],
                    mask: MaskDescriptor(texture: texture, opacity: 1)
                )
            ]
        )

        let frame = try ImageNode
            .recipe(source: .texture(texture), recipe: recipe)
            .applying(C7Brightness(brightness: 0.1))
            .makeFrame()

        let fingerprint = frame.metadata["filterChainFingerprint"] ?? ""
        XCTAssertFalse(fingerprint.isEmpty)
        XCTAssertTrue(fingerprint.contains("C7Brightness"))
        XCTAssertTrue(fingerprint.contains("MaskRegionBlend"))
    }

    func testRenderFrameCarriesExplicitRenderOutputColorSpace() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 2, height: 2, identifier: "RenderedFrameTests.colorContract")
        let frame = try HarbethIO(
            element: texture,
            filters: [RenderedFrameDisplayP3RenderFilter()]
        ).renderFrame(profile: .stablePreview)

        XCTAssertEqual(frame.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
    }

    func testRenderFrameCanDeriveColorSpaceFromSampleBufferAttachments() throws {
        let pixelBuffer = try makeBGRAPixelBuffer(width: 2, height: 2)
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_P3_D65,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_sRGB,
            .shouldPropagate
        )
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }

        let frame = try HarbethIO(
            element: sampleBuffer,
            filters: []
        ).renderFrame(profile: .stablePreview)

        XCTAssertEqual(frame.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
    }

    func testSampleBufferPreviewHostStrategyUsesPassthroughForUnchangedFrame() throws {
        let pixelBuffer = try makeBGRAPixelBuffer(width: 2, height: 2)
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

        let frame = try HarbethIO(element: sampleBuffer, filters: [])
            .renderFrame(profile: .interactiveLatency)
        let hostSampleBuffer = try frame.makePreviewHostSampleBuffer()

        XCTAssertEqual(frame.previewHostStrategyResolution.strategy, .sampleBufferPassthroughHost)
        XCTAssertTrue(frame.previewHostStrategyResolution.sampleBufferHostEligible)
        XCTAssertTrue(frame.previewHostStrategyResolution.sampleBufferHostPayloadAvailable)
        XCTAssertFalse(frame.previewHostStrategyResolution.sampleBufferHostRequiresRematerialization)
        XCTAssertTrue(hostSampleBuffer === sampleBuffer)
    }

    func testSampleBufferPreviewHostStrategyRematerializesAndPreservesMetadata() throws {
        let pixelBuffer = try makeBGRAPixelBuffer(width: 2, height: 2)
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_P3_D65,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_sRGB,
            .shouldPropagate
        )
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            XCTFail("Failed to create sample buffer.")
            return
        }
        CMSetAttachment(
            sampleBuffer,
            key: kCGImagePropertyOrientation,
            value: NSNumber(value: CGImagePropertyOrientation.left.rawValue),
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

        let frame = try HarbethIO(
            element: sampleBuffer,
            filter: C7Brightness(brightness: 0.1)
        ).renderFrame(profile: .interactiveLatency)
        let hostSampleBuffer = try XCTUnwrap(frame.makePreviewHostSampleBuffer())

        XCTAssertEqual(frame.previewHostStrategyResolution.strategy, .sampleBufferRematerializedHost)
        XCTAssertTrue(frame.previewHostStrategyResolution.sampleBufferHostEligible)
        XCTAssertTrue(frame.previewHostStrategyResolution.sampleBufferHostPayloadAvailable)
        XCTAssertTrue(frame.previewHostStrategyResolution.sampleBufferHostRequiresRematerialization)
        XCTAssertFalse(hostSampleBuffer === sampleBuffer)
        XCTAssertEqual(hostSampleBuffer.c7.presentationTimeStamp, sampleBuffer.c7.presentationTimeStamp)
        XCTAssertEqual(hostSampleBuffer.c7.decodeTimeStamp, sampleBuffer.c7.decodeTimeStamp)
        XCTAssertEqual(hostSampleBuffer.c7.duration, sampleBuffer.c7.duration)
        XCTAssertEqual(hostSampleBuffer.c7.contract.frameContract.orientation, .left)
        XCTAssertEqual(hostSampleBuffer.c7.contract.frameContract.mirrorHorizontally, true)
        XCTAssertEqual(hostSampleBuffer.c7.contract.frameContract.followsDeviceOrientation, true)
        XCTAssertEqual(hostSampleBuffer.c7.contract.pixelBufferContract?.colorPrimariesAttachment, .p3D65)
        XCTAssertEqual(hostSampleBuffer.c7.contract.pixelBufferContract?.transferFunctionAttachment, .sRGB)
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

        let frame = try ImageNode.transition(recipe)
            .makeFrame(profile: recipe.profile, derivative: recipe.derivative)

        let fingerprint = frame.metadata["filterChainFingerprint"] ?? ""
        XCTAssertFalse(fingerprint.isEmpty)
        XCTAssertTrue(fingerprint.contains("C7DissolveTransition"))
    }

    func testSourceDescriptorCarriesStableSemanticFingerprint() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let texture = try TextureLoader.makeTexture(width: 4, height: 4, identifier: "RenderedFrameTests")
        let descriptor = ImageSource.texture(texture).descriptor

        XCTAssertEqual(descriptor.semantic, .sourceOriginal)
        XCTAssertEqual(descriptor.sourceTier, .original)
        XCTAssertTrue(descriptor.fingerprint.contains("role=source"))
        XCTAssertTrue(descriptor.fingerprint.contains("tier=original"))
        XCTAssertTrue(descriptor.fingerprint.contains("purpose=processingInput"))
        XCTAssertTrue(descriptor.fingerprint.contains("fidelity=original"))
    }

    private func seedTexture(_ texture: MTLTexture,
                             width: Int,
                             height: Int,
                             bytes: [UInt8]) {
        TextureLoader.replaceTexture(
            texture,
            region: MTLRegionMake2D(0, 0, width, height),
            bytes: bytes,
            packedBytesPerRow: width * 4
        )
    }

    private func makeBGRAPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        try XCTSkipIf(
            status != kCVReturnSuccess,
            "BGRA pixel buffer is unavailable in this environment. CVPixelBufferCreate status=\(status)."
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create BGRA pixel buffer.")
            throw XCTSkip()
        }
        return pixelBuffer
    }
}

private struct RenderedFrameDisplayP3RenderFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderOutputContract: RenderOutputContract {
        RenderOutputContract(colorSpace: .displayP3)
    }
}

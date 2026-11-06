import XCTest
import Metal
@testable import Harbeth

final class RenderParityTests: XCTestCase {
    private func makeTexture() throws -> MTLTexture {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable.")
        }
        return try TextureLoader.makeTexture(
            width: 4,
            height: 4,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "RenderParityTests"
        )
    }

    func testPreviewAndExportKeepVisualParityWhileReportingDeliveryDifferences() throws {
        let texture = try makeTexture()
        let io = HarbethIO(element: texture, filters: [
            C7Brightness(brightness: 0.15),
            C7Contrast(contrast: 1.08)
        ])
        let preview = try io.makeRenderRequest(profile: .stablePreview)
        let export = try io.makeRenderRequest(profile: .exportQuality)

        let report = preview.parityReport(comparedTo: export)

        XCTAssertTrue(report.isVisuallyEquivalent)
        XCTAssertFalse(report.isExactlyEquivalent)
        XCTAssertTrue(report.visualDifferences.isEmpty)
        XCTAssertTrue(report.deliveryDifferences.contains { $0.field == .profile })
        XCTAssertTrue(report.deliveryDifferences.contains { $0.field == .renderIntent })
        XCTAssertTrue(report.deliveryDifferences.contains { $0.field == .derivative })
    }

    func testChangedEditOrSamplerIsReportedAsVisualDifference() throws {
        let texture = try makeTexture()
        let baseline = try ImageNode
            .source(.texture(texture))
            .applying(C7Brightness(brightness: 0.1))
            .makeRenderRequest()
        let changedEdit = try ImageNode
            .source(.texture(texture))
            .applying(C7Brightness(brightness: 0.3))
            .makeRenderRequest()
        let changedSampler = try ImageNode
            .source(.texture(texture))
            .applying(C7Brightness(brightness: 0.1))
            .withSamplerDescriptor(.nearest)
            .makeRenderRequest()

        let editReport = baseline.parityReport(comparedTo: changedEdit)
        let samplerReport = baseline.parityReport(comparedTo: changedSampler)

        XCTAssertFalse(editReport.isVisuallyEquivalent)
        XCTAssertTrue(editReport.visualDifferences.contains { $0.field == .processing })
        XCTAssertFalse(samplerReport.isVisuallyEquivalent)
        XCTAssertTrue(samplerReport.visualDifferences.contains { $0.field == .sampler })
    }

    func testRenderedFrameCarriesTheEvaluatedParityFingerprint() throws {
        let texture = try makeTexture()
        let request = try HarbethIO(element: texture, filters: [C7Brightness(brightness: 0.1)])
            .makeRenderRequest(profile: .stablePreview)

        let frame = try request.renderFrame(metadata: ["purpose": "parity-test"])

        XCTAssertEqual(frame.renderParityFingerprint, request.paritySignature.fingerprint)
        XCTAssertEqual(frame.metadata["purpose"], "parity-test")
    }

    func testUpstreamBrightnessThroughEmptyEditReportsVisualDifferenceAndKeepsPixels() throws {
        let source = ImageNode.texture(try makeOpaqueTexture())
        let first = try source.applying(C7Brightness(brightness: 0.1)).editing(EditRecipe()).makeRenderRequest()
        let second = try source.applying(C7Brightness(brightness: 0.25)).editing(EditRecipe()).makeRenderRequest()
        let firstFrame = try first.renderFrame()
        let secondFrame = try second.renderFrame()
        XCTAssertEqual(Array(try XCTUnwrap(firstFrame.texture.c7.bytes()).prefix(4)), [90, 122, 154, 255])
        XCTAssertEqual(Array(try XCTUnwrap(secondFrame.texture.c7.bytes()).prefix(4)), [128, 160, 192, 255])
        let report = first.parityReport(comparedTo: second)
        XCTAssertFalse(report.isVisuallyEquivalent)
        XCTAssertTrue(report.visualDifferences.contains { $0.field == .processing })
        XCTAssertNotEqual(firstFrame.renderParityFingerprint, secondFrame.renderParityFingerprint)
        XCTAssertEqual(firstFrame.renderParityFingerprint, first.paritySignature.fingerprint)
        XCTAssertEqual(first.withResourceBudget(.unbounded).paritySignature, first.paritySignature)
    }

    func testEmptyEditKeepsUpstreamProcessingEquivalentAndPreviewExportDifferencesSeparate() throws {
        let source = ImageNode.texture(try makeOpaqueTexture()).applying(C7Brightness(brightness: 0.1))
        let direct = try source.makeRenderRequest()
        let edited = source.editing(EditRecipe())
        let preview = try edited.makeRenderRequest(profile: .stablePreview)
        let export = try edited.makeRenderRequest(profile: .exportQuality)
        XCTAssertTrue(direct.parityReport(comparedTo: preview).isVisuallyEquivalent)
        let report = preview.parityReport(comparedTo: export)
        XCTAssertTrue(report.isVisuallyEquivalent)
        XCTAssertFalse(report.isExactlyEquivalent)
        XCTAssertTrue(report.deliveryDifferences.contains { $0.field == .profile })
        XCTAssertTrue(report.deliveryDifferences.contains { $0.field == .derivative })
        let sizes: [OutputSizePolicy] = [.maxPixelSize(2), .exact(C7Size(width: 2, height: 3)), .fit(C7Size(width: 2, height: 3))]
        for size in sizes {
            let thumbnail = ImageDerivativeSpec(
                name: "parity-thumbnail",
                renderIntent: .delivery,
                sourceTier: .thumbnail,
                semantic: RenderProfile.stablePreview.defaultImageSemantic,
                outputSizePolicy: size
            )
            let resized = try edited.makeRenderRequest(profile: .stablePreview, derivative: thumbnail)
            let resizedReport = resized.parityReport(comparedTo: export)
            XCTAssertTrue(resizedReport.isVisuallyEquivalent, "\(resizedReport.visualDifferences)")
            XCTAssertEqual(try resized.renderFrame().texture.width, 2)
        }
    }

    func testDownstreamFiltersAndCacheWrappersKeepUpstreamProcessingIdentity() throws {
        let source = ImageNode.texture(try makeOpaqueTexture())
        func node(_ brightness: Float) -> ImageNode {
            source.applying(C7Brightness(brightness: brightness)).editing(EditRecipe())
                .applyingWithContract(C7Contrast(contrast: 1.1))
                .applying(C7Saturation(saturation: 0.8))
        }
        let baseline = try node(0.1).withCachePolicy(.transient).makeRenderRequest()
        let changed = try node(0.25).withCachePolicy(.persistent).makeRenderRequest()
        let same = try node(0.1).withCachePolicy(.persistent).makeRenderRequest()
        XCTAssertFalse(baseline.parityReport(comparedTo: changed).isVisuallyEquivalent)
        XCTAssertTrue(baseline.parityReport(comparedTo: same).isVisuallyEquivalent)
    }

    func testNestedEmptyEditsKeepNonCommutativeFilterOrder() throws {
        let source = ImageNode.texture(try makeOpaqueTexture())
        let first = try source.applying(C7Brightness(brightness: 0.1)).editing(EditRecipe())
            .applying(C7Contrast(contrast: 1.5)).editing(EditRecipe()).makeRenderRequest()
        let second = try source.applying(C7Contrast(contrast: 1.5)).editing(EditRecipe())
            .applying(C7Brightness(brightness: 0.1)).editing(EditRecipe()).makeRenderRequest()
        XCTAssertNotEqual(try first.renderFrame().texture.c7.bytes(), try second.renderFrame().texture.c7.bytes())
        XCTAssertFalse(first.parityReport(comparedTo: second).isVisuallyEquivalent)
    }

    func testNestedLocalEffectsRetainProcessingAndDeliveryParity() throws {
        let texture = try makeOpaqueTexture()
        let source = ImageNode.texture(texture)
        let mask = try MaskDescriptor(texture: makeOpaqueTexture(pixel: [255, 255, 255, 255]), component: .red)
        func node(_ brightness: Float) -> ImageNode {
            let effect = LocalEffectRecipe(filters: [C7Brightness(brightness: brightness)], mask: mask)
            return source.editing(EditRecipe(localEffects: [effect])).editing(EditRecipe())
        }
        let preview = try node(0.1).makeRenderRequest(profile: .stablePreview)
        let export = try node(0.1).makeRenderRequest(profile: .exportQuality)
        let changed = try node(0.25).makeRenderRequest(profile: .stablePreview)
        XCTAssertTrue(preview.parityReport(comparedTo: export).isVisuallyEquivalent)
        XCTAssertFalse(preview.parityReport(comparedTo: changed).isVisuallyEquivalent)
        XCTAssertNotEqual(try preview.renderFrame().texture.c7.bytes(), try changed.renderFrame().texture.c7.bytes())
    }

    func testNonemptyEditKeepsUpstreamIdentityInRequestRecipeAndSnapshot() throws {
        let source = ImageNode.texture(try makeOpaqueTexture())
        let edit = EditRecipe(geometry: ImageTransformRecipe(targetSize: CGSize(width: 2, height: 2), aspectPolicy: .fit))
        let first = source.applying(C7Brightness(brightness: 0.1)).editing(edit)
        let second = source.applying(C7Brightness(brightness: 0.25)).editing(edit)
        let request = try first.makeRenderRequest()
        let changed = try second.makeRenderRequest()
        XCTAssertFalse(request.parityReport(comparedTo: changed).isVisuallyEquivalent)
        XCTAssertEqual(request.renderRecipe?.processingFingerprint, try first.makeRenderRecipe().processingFingerprint)
        XCTAssertEqual(try first.makeDebugSnapshot().renderRecipe?.processingFingerprint, request.renderRecipe?.processingFingerprint)
        XCTAssertNotEqual(try first.makeDebugSnapshot(), try second.makeDebugSnapshot())
        let frame = try request.renderFrame()
        XCTAssertEqual(frame.texture.width, 2)
        XCTAssertEqual(frame.texture.height, 2)
        XCTAssertNotEqual(frame.texture.c7.bytes(), try changed.renderFrame().texture.c7.bytes())
    }

    func testUpstreamProcessingRoundTripsAndLegacyRecipeRemainsDecodable() throws {
        let source = ImageNode.texture(try makeOpaqueTexture())
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let simple = try source.editing(EditRecipe()).makeRenderRecipe()
        let simpleData = try encoder.encode(simple)
        let simpleObject = try XCTUnwrap(JSONSerialization.jsonObject(with: simpleData) as? [String: Any])
        XCTAssertNil(simpleObject["upstreamProcessingFingerprint"])
        XCTAssertEqual(try decoder.decode(RenderRecipe.self, from: simpleData), simple)

        let node = source.applying(C7Brightness(brightness: 0.1)).editing(EditRecipe())
            .applying(C7Contrast(contrast: 1.2)).withCachePolicy(.persistent)
        let recipe = try node.makeRenderRecipe()
        let encoded = try encoder.encode(recipe)
        let decoded = try decoder.decode(RenderRecipe.self, from: encoded)
        XCTAssertEqual(decoded, recipe)
        XCTAssertEqual(decoded.processingFingerprint, recipe.processingFingerprint)
        XCTAssertEqual(decoded.fingerprint, recipe.fingerprint)
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNotNil(legacyObject.removeValue(forKey: "upstreamProcessingFingerprint"))
        let legacy = try decoder.decode(RenderRecipe.self, from: JSONSerialization.data(withJSONObject: legacyObject))
        XCTAssertNil(legacy.upstreamProcessingFingerprint)
        XCTAssertEqual(legacy.filters, recipe.filters)
        XCTAssertEqual(legacy.outputDerivative, recipe.outputDerivative)

        let snapshot = try node.makeDebugSnapshot()
        XCTAssertEqual(try decoder.decode(RenderGraphDebugSnapshot.self, from: encoder.encode(snapshot)), snapshot)
    }

    func testDeliveryResizeDoesNotHideUserGeometryResize() throws {
        let source = ImageNode.texture(try makeOpaqueTexture()).applying(C7Brightness(brightness: 0.1))
        let thumbnail = ImageDerivativeSpec(
            name: "geometry-thumbnail", renderIntent: .delivery, sourceTier: .thumbnail,
            semantic: RenderProfile.stablePreview.defaultImageSemantic, outputSizePolicy: .maxPixelSize(2)
        )
        let firstNode = source.editing(EditRecipe(geometry: ImageTransformRecipe(targetSize: CGSize(width: 2, height: 2), aspectPolicy: .fit)))
        let secondNode = source.editing(EditRecipe(geometry: ImageTransformRecipe(targetSize: CGSize(width: 3, height: 3), aspectPolicy: .fit)))
        XCTAssertNotEqual(firstNode.resolutionFingerprint(), secondNode.resolutionFingerprint(), "不同声明几何不能命中同一计划键。")
        let first = try firstNode.makeRenderRequest(derivative: thumbnail)
        let second = try secondNode.makeRenderRequest(derivative: thumbnail)
        XCTAssertFalse(first.parityReport(comparedTo: second).isVisuallyEquivalent)
        XCTAssertEqual(try first.renderFrame().texture.width, 2)
        XCTAssertEqual(try second.renderFrame().texture.width, 2)
        XCTAssertEqual(first.renderRecipe?.filters.count, 1)
        XCTAssertEqual(second.renderRecipe?.filters.count, 1)
        XCTAssertNotEqual(first.renderRecipe?.filters, second.renderRecipe?.filters)

        HarbethContext.shared.removeAllRenderPlans()
        let firstFrame = try firstNode.applying(C7Brightness(brightness: 0)).makeFrame()
        let secondFrame = try secondNode.applying(C7Brightness(brightness: 0)).makeFrame()
        XCTAssertEqual(firstFrame.texture.width, 2)
        XCTAssertEqual(secondFrame.texture.width, 3)
    }

    func testUpstreamComputeSamplerIsNotLostAtEditBoundary() throws {
        let source = ImageNode.texture(try makeSamplerTexture())
        let firstNode = source.applying(C7Rotate(angle: 17)).withSamplerDescriptor(.nearest).editing(EditRecipe())
        let secondNode = source.applying(C7Rotate(angle: 17)).withSamplerDescriptor(.default).editing(EditRecipe())
        let first = try firstNode.makeRenderRequest()
        let second = try secondNode.makeRenderRequest()
        XCTAssertEqual(first.diagnostics.samplerDescriptor, .default)
        XCTAssertEqual(second.diagnostics.samplerDescriptor, .default)
        XCTAssertNotEqual(try first.renderFrame().texture.c7.bytes(), try second.renderFrame().texture.c7.bytes())
        XCTAssertFalse(first.parityReport(comparedTo: second).isVisuallyEquivalent)
        XCTAssertTrue(first.parityReport(comparedTo: second).visualDifferences.contains { $0.field == .processing })
    }

    func testUpstreamRenderSamplerSurvivesDownstreamFiltersAndCache() throws {
        let source = ImageNode.texture(try makeSamplerTexture())
        func node(_ sampler: ImageSamplerDescriptor) -> ImageNode {
            source.applying(ParitySamplerResize()).withSamplerDescriptor(sampler)
                .applying(C7Brightness(brightness: 0)).withCachePolicy(.persistent)
                .editing(EditRecipe()).applying(C7Contrast(contrast: 1))
        }
        let firstNode = node(.nearest), secondNode = node(.default)
        let first = try firstNode.makeRenderRequest()
        let second = try secondNode.makeRenderRequest()
        XCTAssertNotEqual(try first.renderFrame().texture.c7.bytes(), try second.renderFrame().texture.c7.bytes())
        XCTAssertFalse(first.parityReport(comparedTo: second).isVisuallyEquivalent)
        XCTAssertEqual(first.renderRecipe?.processingFingerprint, try firstNode.makeRenderRecipe().processingFingerprint)
        XCTAssertEqual(try firstNode.makeDebugSnapshot().renderRecipe?.processingFingerprint, first.renderRecipe?.processingFingerprint)
    }

    func testSamplerHistoryPreservesDeliveryParityAndCodec() throws {
        let source = ImageNode.texture(try makeSamplerTexture())
        let node = source.applying(ParitySamplerResize()).withSamplerDescriptor(.nearest)
            .editing(EditRecipe()).withSamplerDescriptor(.default).withCachePolicy(.persistent)
        let preview = try node.makeRenderRequest(profile: .stablePreview)
        let export = try node.makeRenderRequest(profile: .exportQuality)
        let thumbnail = ImageDerivativeSpec(
            name: "sampler-thumbnail", renderIntent: .delivery, sourceTier: .thumbnail,
            semantic: RenderProfile.stablePreview.defaultImageSemantic, outputSizePolicy: .maxPixelSize(3)
        )
        let resized = try node.makeRenderRequest(derivative: thumbnail)
        XCTAssertTrue(preview.parityReport(comparedTo: export).isVisuallyEquivalent)
        XCTAssertTrue(resized.parityReport(comparedTo: export).isVisuallyEquivalent)
        let recipe = try XCTUnwrap(preview.renderRecipe)
        XCTAssertEqual(recipe.processingFingerprint, try node.makeRenderRecipe().processingFingerprint)
        XCTAssertEqual(try node.makeDebugSnapshot().renderRecipe?.processingFingerprint, recipe.processingFingerprint)
        let decoded = try JSONDecoder().decode(RenderRecipe.self, from: JSONEncoder().encode(recipe))
        XCTAssertEqual(decoded, recipe)
        XCTAssertEqual(try preview.renderFrame().renderParityFingerprint, preview.paritySignature.fingerprint)
    }

    func testInnerSamplerOverrideKeepsItsPriorityThroughKernelAndOuterWrapper() throws {
        let source = ImageNode.texture(try makeSamplerTexture()).applyingWithContract(C7Rotate(angle: 17))
        let inner = source.withSamplerDescriptor(.nearest)
        let firstNode = inner.withSamplerDescriptor(.default).editing(EditRecipe())
        let sameNode = inner.editing(EditRecipe())
        let changedNode = source.withSamplerDescriptor(.default).withSamplerDescriptor(.default).editing(EditRecipe())
        let first = try firstNode.makeRenderRequest()
        let same = try sameNode.makeRenderRequest()
        let changed = try changedNode.makeRenderRequest()
        XCTAssertTrue(first.parityReport(comparedTo: same).isVisuallyEquivalent)
        XCTAssertFalse(first.parityReport(comparedTo: changed).isVisuallyEquivalent)
        XCTAssertEqual(try first.renderFrame().texture.c7.bytes(), try same.renderFrame().texture.c7.bytes())
        XCTAssertEqual(first.renderRecipe?.processingFingerprint, try firstNode.makeRenderRecipe().processingFingerprint)
    }

    func testDefaultSamplerKeepsPlainRecipeIdentity() throws {
        let source = ImageNode.texture(try makeSamplerTexture())
        let node = source.applying(C7Rotate(angle: 17)).editing(EditRecipe())
        let plain = try node.makeRenderRecipe()
        let wrapped = try node.withSamplerDescriptor(.default).makeRenderRecipe()
        XCTAssertEqual(plain, wrapped)
        XCTAssertFalse(plain.processingFingerprint.contains("|sampler={"))
    }

    func testSamplerDescriptionsMatchRequestsForEditTransitionAndLayerRoots() throws {
        let texture = try makeSamplerTexture()
        let source = ImageSource.texture(texture)
        let roots: [ImageNode] = [
            ImageNode.source(source).editing(EditRecipe(geometry: ImageTransformRecipe(rotationDegrees: 17))),
            .transition(TransitionRecipe(from: source, to: source, kernel: .dissolve, progress: 0.3)),
            .layerComposite(LayerCompositeRecipe(background: source, layers: [ImageLayer(content: source)]))
        ]
        for root in roots {
            let node = root.withSamplerDescriptor(.nearest)
            let request = try node.makeRenderRequest()
            let recipe = try node.makeRenderRecipe()
            XCTAssertFalse(recipe.filters.isEmpty)
            XCTAssertTrue(recipe.filters.allSatisfy { $0.executionContractFingerprint.contains("sampler={\(ImageSamplerDescriptor.nearest.fingerprint)}") })
            XCTAssertEqual(request.renderRecipe?.processingFingerprint, recipe.processingFingerprint)
            XCTAssertEqual(try node.makeDebugSnapshot().renderRecipe?.processingFingerprint, recipe.processingFingerprint)
        }
    }

    private func makeSamplerTexture() throws -> MTLTexture {
        let texture = try makeOpaqueTexture()
        var pixels: [UInt8] = []
        for y in 0..<4 {
            for x in 0..<4 {
                pixels += [UInt8((x + y) % 2 == 0 ? 255 : 0), UInt8(16 + x * 48), UInt8(16 + y * 48), 255]
            }
        }
        pixels.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 16)
        }
        return texture
    }

    private func makeOpaqueTexture(pixel: [UInt8] = [64, 96, 128, 255]) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 4,
            height: 4,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let pixels = Array(repeating: pixel, count: 16).flatMap { $0 }
        pixels.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 16)
        }
        return texture
    }
}

private struct ParitySamplerResize: RenderProtocol {
    var modifier: ModifierEnum { .render(vertex: "basicVertex", fragment: "basicFragment") }
    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }
    func resize(input size: C7Size) -> C7Size { C7Size(width: 7, height: 5) }
}

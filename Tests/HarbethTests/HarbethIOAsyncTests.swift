import XCTest
@testable import Harbeth

final class HarbethIOAsyncTests: XCTestCase {

    func testFilterMetadataDefaultsStayNonBreaking() {
        let filter = C7Brightness(brightness: 0.2)
        XCTAssertEqual(filter.stableTypeID, "C7Brightness")
        XCTAssertTrue(filter.parameterDescriptors.isEmpty)
        XCTAssertNil(filter.intensityHint)
    }

    func testRenderProfileConfiguresCurrentFlags() {
        let base = HarbethIO(element: "seed", filters: [])

        let interactive = base.configured(for: .interactiveLatency)
        XCTAssertTrue(interactive.transmitOutputRealTimeCommit)
        XCTAssertFalse(interactive.enableDoubleBuffer)
        XCTAssertFalse(interactive.createDestTexture)

        let stable = base.configured(for: .stablePreview)
        XCTAssertFalse(stable.transmitOutputRealTimeCommit)
        XCTAssertTrue(stable.enableDoubleBuffer)
        XCTAssertTrue(stable.createDestTexture)

        let export = base.configured(for: .exportQuality)
        XCTAssertFalse(export.transmitOutputRealTimeCommit)
        XCTAssertTrue(export.enableDoubleBuffer)
        XCTAssertTrue(export.createDestTexture)
    }

    func testAsyncTransmitOutputMatchesCallbackResult() async throws {
        let io = HarbethIO(element: "seed", filters: [])

        let callbackValue = try await withCheckedThrowingContinuation { continuation in
            io.transmitOutput(complete: { result in
                continuation.resume(with: result)
            })
        }

        let asyncValue = try await io.transmitOutput()

        XCTAssertEqual(callbackValue, "seed")
        XCTAssertEqual(asyncValue, callbackValue)
    }

    func testFilterRecipeDescriptorUsesStableFingerprint() {
        let filter = C7Brightness(brightness: 0.2)
        let descriptor = filter.recipeDescriptor

        XCTAssertEqual(descriptor.stableTypeID, "C7Brightness")
        XCTAssertEqual(descriptor.modifier, "compute:C7Brightness")
        XCTAssertEqual(descriptor.parameterValues, ["0.200000"])
        XCTAssertTrue(descriptor.fingerprint.contains("C7Brightness"))
    }

    func testRenderRecipeCarriesProfileAlphaOrientationAndFilterChain() throws {
        let image = try makeFixtureCGImage()
        let io = HarbethIO<CGImage>(
            element: image,
            filters: [C7Brightness(brightness: 0.2), C7Contrast(contrast: 1.1)]
        )

        let recipe: RenderRecipe = try io.renderRecipe(profile: RenderProfile.stablePreview)

        XCTAssertEqual(recipe.renderProfile, "stablePreview")
        XCTAssertEqual(recipe.renderIntent, .stable)
        XCTAssertEqual(recipe.source.kind, "cgImage")
        XCTAssertEqual(recipe.source.sourceTier, .original)
        XCTAssertEqual(recipe.source.cachePolicy, ImageCachePolicy.persistent)
        XCTAssertEqual(recipe.source.semantic, .sourceOriginal)
        XCTAssertEqual(recipe.outputCachePolicy, ImageCachePolicy.transient)
        XCTAssertEqual(recipe.outputSemantic.role, .derivative)
        XCTAssertEqual(recipe.outputSemantic.purpose, .stable)
        XCTAssertEqual(recipe.outputSemantic.fidelity, .displayOptimized)
        XCTAssertEqual(recipe.alphaType, AlphaType.premultiplied)
        XCTAssertEqual(recipe.orientation, FrameOrientation.up)
        XCTAssertEqual(recipe.filters.count, 2)
        XCTAssertTrue(recipe.fingerprint.contains("C7Brightness"))
        XCTAssertTrue(recipe.fingerprint.contains("C7Contrast"))
        XCTAssertTrue(recipe.fingerprint.contains("intent=stable"))
        XCTAssertTrue(recipe.fingerprint.contains("outputCache=transient"))
        XCTAssertTrue(recipe.fingerprint.contains("purpose=stable"))
    }

    func testRenderRecipeCanCarryDerivativeSpec() throws {
        let image = try makeFixtureCGImage()
        let io = HarbethIO<CGImage>(
            element: image,
            filters: [C7Brightness(brightness: 0.2)]
        )
        let derivative = ImageDerivativeSpec(
            name: "panelThumbnail",
            renderIntent: .delivery,
            sourceTier: .thumbnail,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .thumbnail, fidelity: .thumbnailOptimized),
            outputSizePolicy: .maxPixelSize(160)
        )

        let recipe = try io.renderRecipe(profile: .stablePreview, derivative: derivative)

        XCTAssertEqual(recipe.renderIntent, .delivery)
        XCTAssertEqual(recipe.outputDerivative.name, "panelThumbnail")
        XCTAssertEqual(recipe.outputDerivative.sourceTier, .thumbnail)
        XCTAssertEqual(recipe.outputDerivative.outputSizePolicy, .maxPixelSize(160))
        XCTAssertTrue(recipe.fingerprint.contains("name=panelThumbnail"))
        XCTAssertTrue(recipe.fingerprint.contains("output=maxPixel:160"))
    }

    func testRenderRequestCarriesStableContractsAndDeferredExecution() throws {
        let image = try makeFixtureCGImage()
        let io = HarbethIO<CGImage>(
            element: image,
            filters: [C7Brightness(brightness: 0.2)]
        )

        let request = try io.makeRenderRequest(profile: .stablePreview)
        let frame = try request.renderFrame(metadata: ["request": "deferred"])

        XCTAssertEqual(request.compilationSource, .filtersPrimitive)
        XCTAssertEqual(request.profile, .stablePreview)
        XCTAssertEqual(request.derivative.renderIntent, .stable)
        XCTAssertEqual(request.source.kind, "cgImage")
        XCTAssertEqual(request.outputCachePolicy, .transient)
        XCTAssertEqual(request.renderRecipe?.renderIntent, .stable)
        XCTAssertEqual(frame.metadata["request"], "deferred")
        XCTAssertEqual(frame.profile, .stablePreview)
    }

    private func makeFixtureCGImage() throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytes: [UInt8] = [255, 0, 0, 255]
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: 1,
                                  height: 1,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: 4,
                                  space: colorSpace,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            throw XCTSkip("Failed to create CGImage fixture.")
        }
        return image
    }
}

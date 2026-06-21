import XCTest
import ImageIO
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

    func testAsyncTransmitManagedTexturePrewarmsLifecycleReservations() async throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")
        Shared.shared.deinitDevice()
        defer { Shared.shared.deinitDevice() }

        let input = try makeTexture(width: 32, height: 24, pixel: [120, 80, 40, 255])
        let io = HarbethIO(
            element: input,
            filters: [
                C7Brightness(brightness: 0.1),
                C7Resize(width: 16, height: 12),
                C7Contrast(contrast: 1.1)
            ]
        ).configured(for: .stablePreview)

        let output = try await withCheckedThrowingContinuation { continuation in
            io.transmitManagedTexture { result in
                continuation.resume(with: result)
            }
        }

        let snapshot = Shared.shared.defaultTextureAllocator.makeSnapshot()

        XCTAssertGreaterThan(snapshot.textureReuseHitCount, 0)
        XCTAssertGreaterThan(snapshot.textureRequestCount, 0)
        XCTAssertNotNil(output.lease)
        output.lease?.release()
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

    func testHarbethIOC7ImageOutputAppliesExplicitRenderOutputColorSpace() throws {
        let cgImage = try makeFixtureCGImage()
        let image = C7Image(cgImage: cgImage)

        let output: C7Image = try HarbethIO(
            element: image,
            filters: [HarbethIOC7ImageDisplayP3RenderFilter()]
        ).output()

        XCTAssertEqual(output.c7.toCGImage()?.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
    }

    func testHarbethIOC7ImageOutputPreservesSourceColorSpaceWithoutExplicitContract() throws {
        let displayP3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let cgImage = try makeFixtureCGImage(colorSpace: displayP3)
        let image = C7Image(cgImage: cgImage)

        let output: C7Image = try HarbethIO(
            element: image,
            filters: [C7Brightness(brightness: 0.0)]
        ).output()

        XCTAssertEqual(output.c7.toCGImage()?.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
    }

    func testC7ImageEncodedPNGDataPreservesDisplayP3ColorSpace() throws {
        let displayP3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let image = C7Image(cgImage: try makeFixtureCGImage(colorSpace: displayP3))

        let data = try XCTUnwrap(image.c7.encodedPNGData())

        XCTAssertEqual(decodedImageColorSpaceName(from: data), CGColorSpace.displayP3 as String)
    }

    func testHarbethIORenderJPEGDataAppliesExplicitRenderOutputColorSpace() throws {
        let image = C7Image(cgImage: try makeFixtureCGImage())
        let data = try HarbethIO(
            element: image,
            filters: [HarbethIOC7ImageDisplayP3RenderFilter()]
        ).renderJPEGData()

        XCTAssertEqual(decodedImageColorSpaceName(from: data), CGColorSpace.displayP3 as String)
    }

    private func makeFixtureCGImage(colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()) throws -> CGImage {
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

    private func decodedImageColorSpaceName(from data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image.colorSpace?.name as String?
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = Shared.shared.defaultDevice.device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        var pixels = Array(repeating: UInt8(0), count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = pixel[0]
            pixels[index + 1] = pixel[1]
            pixels[index + 2] = pixel[2]
            pixels[index + 3] = pixel[3]
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }
}

private struct HarbethIOC7ImageDisplayP3RenderFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderOutputContract: RenderOutputContract {
        RenderOutputContract(colorSpace: .displayP3)
    }
}

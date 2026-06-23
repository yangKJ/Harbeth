import XCTest
import Metal
import CoreMedia
@testable import Harbeth

final class ImageNodeValidationWorkbenchTests: XCTestCase {

    func testDataSourceValidationSceneProducesDataSourceRequest() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [120, 80, 40, 255])
        let image = try XCTUnwrap(input.c7.toImage())
        let data = try XCTUnwrap(image.c7.encodedPNGData())
        let node = ImageNode
            .data(data)
            .applying(filters: [
                C7Brightness(brightness: 0.12),
                C7Contrast(contrast: 1.08)
            ])

        let frame = try node.makeFrame(profile: .stablePreview)
        let request = try node.makeRenderRequest(profile: .stablePreview)
        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)

        XCTAssertEqual(frame.texture.width, 4)
        XCTAssertEqual(request.source.kind, "data")
        XCTAssertEqual(diagnostics.sourceKind, "data")
        XCTAssertEqual(request.compilationSource, .nodeGraph)
    }

    func testURLAssetValidationSceneProducesAssetSourceRequest() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [40, 140, 220, 255])
        let image = try XCTUnwrap(input.c7.toImage())
        let data = try XCTUnwrap(image.c7.encodedPNGData())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try data.write(to: url, options: .atomic)

        let asset = ImageAsset(
            storage: .url(url),
            loadingOptions: .init(sizePolicy: .original, flipsVertically: false)
        )
        let node = ImageNode
            .asset(asset)
            .applying(C7Saturation(saturation: 1.15))

        let frame = try node.makeFrame(profile: .stablePreview)
        let request = try node.makeRenderRequest(profile: .stablePreview)
        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)

        XCTAssertEqual(frame.texture.width, 4)
        XCTAssertEqual(request.source.kind, "urlAsset")
        XCTAssertEqual(diagnostics.sourceKind, "urlAsset")
        XCTAssertEqual(request.compilationSource, .nodeGraph)
    }

    func testTransitionValidationSceneProducesTransitionSnapshot() throws {
        let from = try makeTexture(width: 4, height: 4, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 4, height: 4, pixel: [0, 0, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .directionalWipe(angleDegrees: 30, softness: 0.08),
            progress: 0.35
        )
        let node = ImageNode.transition(recipe)

        let frame = try node.makeFrame(profile: recipe.profile, derivative: recipe.derivative)
        let request = try node.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
        let snapshot = try node.makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(frame.texture.width, 4)
        XCTAssertEqual(request.compilationSource, .transition)
        XCTAssertEqual(snapshot.diagnostics.compilationSource, RenderCompilationSource.transition.rawValue)
        XCTAssertTrue(snapshot.summary.contains("source=transition"))
    }

    func testSampleBufferValidationScenePreservesSampleBufferSourceContract() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [220, 180, 80, 255])
        let image = try XCTUnwrap(input.c7.toImage())
        let cgImage = try XCTUnwrap(image.c7.toCGImage())
        let pixelBuffer = try XCTUnwrap(cgImage.c7.toPixelBuffer())
        var sampleBuffer = try XCTUnwrap(pixelBuffer.c7.toCMSampleBuffer())
        sampleBuffer.c7.isNotSync = true

        let node = ImageNode
            .sampleBuffer(sampleBuffer)
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        targetSize: CGSize(width: 3, height: 3),
                        aspectPolicy: .fit
                    )
                )
            )
            .applying(C7Brightness(brightness: 0.08))

        let frame = try node.makeFrame(profile: RenderProfile.stablePreview)
        let request = try node.makeRenderRequest(profile: RenderProfile.stablePreview)
        let snapshot = try node.makeDebugSnapshot(profile: RenderProfile.stablePreview)

        XCTAssertEqual(frame.texture.width, 3)
        XCTAssertEqual(request.compilationSource, RenderCompilationSource.editRecipe)
        XCTAssertEqual(request.source.kind, "sampleBuffer")
        XCTAssertEqual(request.source.sampleBufferContract?.attachments.notSync, true)
        XCTAssertTrue(snapshot.summary.contains("origin=sampleBuffer"))
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
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
            XCTFail("Failed to create texture.")
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
}

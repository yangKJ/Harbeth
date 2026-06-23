import XCTest
import Metal
import CoreGraphics
import CoreVideo
import CoreMedia
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif
@testable import Harbeth

final class HarbethPluginTests: XCTestCase {

    func testPluginSourceOutputsPreserveSourceDescriptors() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [120, 80, 40, 255])
        let image = try XCTUnwrap(input.c7.toImage())
        let cgImage = try XCTUnwrap(image.c7.toCGImage())
        let pixelBuffer = try XCTUnwrap(cgImage.c7.toPixelBuffer())
        let sampleBuffer = try XCTUnwrap(pixelBuffer.c7.toCMSampleBuffer())

        let cases: [(HarbethPluginOutput, String)] = [
            (.texture(input), "texture"),
            (.image(image), "image"),
            (.cgImage(cgImage), "cgImage"),
            (.pixelBuffer(pixelBuffer), "pixelBuffer"),
            (.sampleBuffer(sampleBuffer), "sampleBuffer")
        ]

        for (output, expectedKind) in cases {
            let descriptor = try output.sourceDescriptor()
            let node = try ImageNode.source(output)
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
        let pluginOutput = HarbethPluginOutput.filters([
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

    func testBareMaskPluginOutputFailsWithExplicitError() throws {
        let input = try makeTexture(pixel: [120, 120, 120, 255])
        let maskTexture = try makeTexture(pixel: [255, 255, 255, 255])
        let node = ImageNode.source(ImageSource.texture(input))

        XCTAssertThrowsError(
            try node.applying(pluginOutput: .mask(MaskDescriptor(texture: maskTexture)))
        ) { error in
            guard case HarbethError.configurationInvalid(let description) = error else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(description.contains("mask cannot be applied directly"))
        }
    }

    func testImageNodePreviewFrameCarriesDiagnostics() throws {
        let input = try makeTexture(pixel: [140, 100, 60, 255])
        let frame = try ImageNode
            .source(.texture(input))
            .applying(C7Brightness(brightness: 0.1))
            .makePreviewFrame(profile: .stablePreview)

        XCTAssertTrue(frame.texture.width > 0)
        XCTAssertEqual(frame.sourceDescriptor.kind, "texture")
        XCTAssertEqual(frame.profile, .stablePreview)
        XCTAssertEqual(frame.diagnostics?.compilationSource, .nodeGraph)
    }

    #if canImport(UIKit) && !os(watchOS)
    func testRenderViewDisplayUpdatesPreviewFrameWithoutLosingTextureCompatibility() throws {
        let texture = try makeTexture(width: 4, height: 2, pixel: [80, 120, 160, 255])
        let previewFrame = HarbethPreviewFrame(
            texture: texture,
            sourceDescriptor: ImageSource.texture(texture).descriptor,
            profile: .stablePreview
        )
        let view = RenderView(frame: CGRect(x: 0, y: 0, width: 64, height: 32), device: MTLCreateSystemDefaultDevice())

        view.layoutSubviews()
        view.display(previewFrame)

        XCTAssertTrue(view.texture === texture)
        XCTAssertEqual(view.currentPreviewFrame?.sourceDescriptor.kind, "texture")
        XCTAssertEqual(view.drawableSize.width, 64)
        XCTAssertEqual(view.drawableSize.height, 32)

        let replacement = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        view.texture = replacement

        XCTAssertTrue(view.texture === replacement)
        XCTAssertNil(view.currentPreviewFrame)
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

private struct MockFilterPlugin: HarbethFilterPlugin {
    let output: HarbethPluginOutput

    var pluginIdentifier: String {
        "mock.filter"
    }

    func makeOutput(frame: RenderedFrame) throws -> HarbethPluginOutput {
        output
    }
}

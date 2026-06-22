import XCTest
import Metal
@testable import Harbeth

final class ImageNodeRecipeRouteTests: XCTestCase {

    func testEditRecipeNodeProducesTextureFrameAndRequest() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let input = try makeTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])
        let recipe = EditRecipe()
        let node = ImageNode
            .recipe(source: .texture(input), recipe: recipe)
            .applying(C7Brightness(brightness: -0.2))

        let texture = try node.makeTexture()
        let frame = try node.makeFrame(metadata: ["route": "recipe"])
        let request = try node.makeRenderRequest()

        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(frame.profile, .stablePreview)
        XCTAssertEqual(frame.metadata["route"], "recipe")
        XCTAssertEqual(request.compilationSource, .editRecipe)
        XCTAssertEqual(request.source.kind, "texture")
    }

    func testLayerCompositeNodeProducesTextureFrameAndRequest() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let background = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))]
        )
        let node = ImageNode.layerComposite(recipe)

        let texture = try node.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        let frame = try node.makeFrame(profile: recipe.profile, derivative: recipe.derivative, metadata: ["route": "layerComposite"])
        let request = try node.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(texture.width, 2)
        XCTAssertEqual(frame.metadata["route"], "layerComposite")
        XCTAssertEqual(request.compilationSource, .layerComposite)
        XCTAssertEqual(request.source.kind, "texture")
    }

    func testLayerCompositeNodeSamplerDescriptorReachesLayerLocalFilterExecution() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 0])
        let layer = try makeTexture(width: 2, height: 1, pixelRows: [
            [255, 0, 0, 255],
            [0, 0, 255, 255]
        ])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    filters: [RouteSamplerProbeFilter()],
                    normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
                )
            ]
        )

        let linearNode = ImageNode.layerComposite(recipe)
        let nearestNode = linearNode.withSamplerDescriptor(ImageSamplerDescriptor.nearest)

        let linearPixel = try firstPixel(in: linearNode.makeFrame(profile: recipe.profile, derivative: recipe.derivative).texture)
        let nearestPixel = try firstPixel(in: nearestNode.makeFrame(profile: recipe.profile, derivative: recipe.derivative).texture)

        XCTAssertNotEqual(linearPixel.red, nearestPixel.red)
        XCTAssertNotEqual(linearPixel.blue, nearestPixel.blue)
    }

    func testTransitionNodeProducesTextureFrameAndDiagnostics() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable.")

        let from = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 1
        )
        let node = ImageNode.transition(recipe)

        let texture = try node.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        let frame = try node.makeFrame(profile: recipe.profile, derivative: recipe.derivative, metadata: ["route": "transition"])
        let diagnostics = try node.makeDiagnostics(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(texture.width, 2)
        XCTAssertEqual(try firstPixel(in: frame.texture).blue, 255)
        XCTAssertEqual(frame.metadata["route"], "transition")
        XCTAssertEqual(diagnostics.compilationSource, .transition)
        XCTAssertTrue(diagnostics.containsTransitionKernel)
    }

    private func makeTexture(width: Int = 1, height: Int = 1, pixel: [UInt8]) throws -> MTLTexture {
        let bytes = Array(repeating: pixel, count: width * height)
        return try makeTexture(width: width, height: height, pixelRows: bytes)
    }

    private func makeTexture(width: Int, height: Int, pixelRows: [[UInt8]]) throws -> MTLTexture {
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
        let bytes = pixelRows.flatMap { $0 }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable bytes.")
            throw HarbethError.texture2Image
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}

private struct RouteSamplerProbeFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    func resize(input size: C7Size) -> C7Size {
        C7Size(width: 1, height: 1)
    }

    func setupVertices(inputSize: C7Size) -> [Float]? {
        [
            -1.0, -1.0, 0.375, 0.5,
             1.0, -1.0, 0.375, 0.5,
            -1.0,  1.0, 0.375, 0.5,
             1.0,  1.0, 0.375, 0.5
        ]
    }
}

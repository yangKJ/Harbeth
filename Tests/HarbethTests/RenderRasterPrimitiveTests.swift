import Metal
import XCTest
@testable import Harbeth

final class RenderRasterPrimitiveTests: XCTestCase {

    func testVectorMaskTriangulatesConcavePolygon() throws {
        let filter = try RenderVectorMask(points: [
            .init(x: 0.1, y: 0.1),
            .init(x: 0.9, y: 0.1),
            .init(x: 0.5, y: 0.5),
            .init(x: 0.9, y: 0.9),
            .init(x: 0.1, y: 0.9)
        ])
        let vertices = try XCTUnwrap(filter.setupVertices(inputSize: C7Size(width: 32, height: 32)))

        XCTAssertEqual(filter.renderPrimitiveTopology, .triangle)
        XCTAssertEqual(filter.renderRasterSampleCount, 4)
        XCTAssertEqual(vertices.count, (5 - 2) * 3 * 4)
    }

    func testVectorMaskRejectsInvalidContracts() {
        XCTAssertThrowsError(try RenderVectorMask(points: [FreePoint2D.zero, .zero]))
        XCTAssertThrowsError(try RenderVectorMask(
            points: [.zero, .init(x: 0.5, y: 0.5), .init(x: 1, y: 1)]
        ))
        XCTAssertThrowsError(try RenderVectorMask(
            points: [.zero, .init(x: 1, y: 0), .init(x: 0, y: 1)],
            rasterSampleCount: 3
        ))
    }

    func testLayerCompositeDeclaresHardwareSourceOverContract() throws {
        let layer = try makeTexture(width: 2, height: 2)
        let filter = try RenderLayerComposite(
            layerTexture: layer,
            normalizedFrame: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            opacity: 0.75
        )

        XCTAssertEqual(filter.renderBlendMode, .premultipliedSourceOver)
        XCTAssertTrue(filter.renderPreloadsSourceTexture)
        XCTAssertEqual(filter.otherInputTextures.count, 1)
        XCTAssertEqual(filter.factors, [0.75])
    }

    func testVectorMaskResolvesMultisampleCoverage() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil || device?.supportsTextureSampleCount(4) == false, "4x MSAA is unavailable.")
        HarbethContext.shared.recoverExecution()
        let seed = try makeTexture(width: 16, height: 16)
        let filter = try RenderVectorMask(points: [
            .init(x: 0.15, y: 0.15),
            .init(x: 0.85, y: 0.2),
            .init(x: 0.5, y: 0.85)
        ])

        let output: MTLTexture = try HarbethIO(element: seed, filter: filter).output()
        let bytes = try XCTUnwrap(output.c7.bytes())

        XCTAssertEqual(output.sampleCount, 1)
        XCTAssertTrue(output.usage.contains(.renderTarget))
        XCTAssertTrue(bytes.contains { $0 > 0 })
        XCTAssertTrue(bytes.contains(0))
    }

    func testLayerCompositeUsesPremultipliedSourceOverOnGPU() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable.")
        HarbethContext.shared.recoverExecution()
        let background = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let layer = try makeTexture(width: 2, height: 2, pixel: [128, 0, 0, 128])
        let filter = try RenderLayerComposite(layerTexture: layer)

        let output: MTLTexture = try HarbethIO(element: background, filter: filter).output()
        let bytes = try XCTUnwrap(output.c7.bytes())

        XCTAssertEqual(bytes[0], 128, accuracy: 1)
        XCTAssertEqual(bytes[1], 0, accuracy: 1)
        XCTAssertEqual(bytes[2], 127, accuracy: 1)
        XCTAssertEqual(bytes[3], 255, accuracy: 1)
    }

    func testLayerCompositeStagesInPlaceOutputWithoutRenderFeedback() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable.")
        HarbethContext.shared.recoverExecution()
        let background = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let layer = try makeTexture(width: 2, height: 2, pixel: [128, 0, 0, 128])
        let io = HarbethIO(element: background, filter: try RenderLayerComposite(layerTexture: layer))
            .configured(for: .interactiveLatency)

        let output: MTLTexture = try io.output()
        let bytes = try XCTUnwrap(output.c7.bytes())

        XCTAssertTrue(output === background)
        XCTAssertEqual(bytes[0], 128, accuracy: 1)
        XCTAssertEqual(bytes[2], 127, accuracy: 1)
        XCTAssertEqual(bytes[3], 255, accuracy: 1)
    }

    func testLayerCompositeSingleBufferAllocatesRenderTargetUsage() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable.")
        HarbethContext.shared.recoverExecution()
        let background = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let layer = try makeTexture(width: 2, height: 2, pixel: [128, 0, 0, 128])
        let io = HarbethIO(element: background, filter: try RenderLayerComposite(layerTexture: layer))

        let output: MTLTexture = try io.output()

        XCTAssertTrue(output.usage.contains(.renderTarget))
        XCTAssertEqual(try XCTUnwrap(output.c7.bytes())[0], 128, accuracy: 1)
    }

    func testLayerCompositeManagedDoubleBufferAllocatesRenderTargetUsage() throws {
        try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "Metal device is unavailable.")
        HarbethContext.shared.recoverExecution()
        let background = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let layer = try makeTexture(width: 2, height: 2, pixel: [128, 0, 0, 128])
        let io = HarbethIO(element: background, filter: try RenderLayerComposite(layerTexture: layer))

        let managed = try io.renderManagedTexture()
        defer { managed.lease?.release() }

        XCTAssertTrue(managed.texture.usage.contains(.renderTarget))
        XCTAssertEqual(try XCTUnwrap(managed.texture.c7.bytes())[0], 128, accuracy: 1)
    }

    func testLayerCompositeStagesDistinctViewsOfSameTextureResource() throws {
        HarbethContext.shared.recoverExecution()
        guard MTLCreateSystemDefaultDevice() != nil,
              let commandBuffer = HarbethContext.shared.makeCommandBuffer() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget, .pixelFormatView]
        let background = try makeTexture(
            width: 2,
            height: 2,
            pixel: [0, 0, 255, 255],
            usage: usage
        )
        let layer = try makeTexture(width: 2, height: 2, pixel: [128, 0, 0, 128])
        let sourceView = try XCTUnwrap(background.makeTextureView(pixelFormat: .rgba8Unorm))
        let destinationView = try XCTUnwrap(background.makeTextureView(pixelFormat: .rgba8Unorm))
        let filter = try RenderLayerComposite(layerTexture: layer)

        _ = try filter.applyAtTexture(
            form: sourceView,
            to: destinationView,
            for: commandBuffer
        )
        try commandBuffer.commitAndWaitUntilCompleted(identifier: "RenderLayerComposite.TextureViews")
        HarbethContext.shared.recycleCommandBuffer(commandBuffer)
        let bytes = try XCTUnwrap(background.c7.bytes())

        XCTAssertFalse(sourceView === destinationView)
        XCTAssertEqual(bytes[0], 128, accuracy: 1)
        XCTAssertEqual(bytes[2], 127, accuracy: 1)
    }

    private func makeTexture(width: Int,
                             height: Int,
                             pixel: [UInt8] = [0, 0, 0, 0],
                             usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        let bytes = Array(repeating: pixel, count: width * height).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }
}

import XCTest
import Metal
@testable import Harbeth

final class RenderMeshWarpTests: XCTestCase {

    func testRejectsGridSmallerThanTwoByTwo() {
        XCTAssertThrowsError(try RenderMeshWarp(rows: 1, columns: 2, controlPoints: [])) { error in
            XCTAssertEqual(
                error as? RenderMeshWarp.ValidationError,
                .insufficientGridDimensions(rows: 1, columns: 2)
            )
        }
    }

    func testRejectsIncorrectControlPointCount() {
        XCTAssertThrowsError(
            try RenderMeshWarp(rows: 2, columns: 2, controlPoints: [.zero, .zero, .zero])
        ) { error in
            XCTAssertEqual(
                error as? RenderMeshWarp.ValidationError,
                .incorrectControlPointCount(expected: 4, actual: 3)
            )
        }
    }

    func testRejectsNonFiniteControlPoint() {
        XCTAssertThrowsError(
            try RenderMeshWarp(
                rows: 2,
                columns: 2,
                controlPoints: [.zero, .zero, .init(x: .infinity, y: 0), .zero]
            )
        ) { error in
            XCTAssertEqual(error as? RenderMeshWarp.ValidationError, .nonFiniteControlPoint(index: 2))
        }
    }

    func testRejectsGridAboveSafeControlPointLimitBeforeAllocation() {
        XCTAssertThrowsError(try RenderMeshWarp.identity(rows: 65, columns: 65)) { error in
            XCTAssertEqual(
                error as? RenderMeshWarp.ValidationError,
                .tooManyControlPoints(maximum: 4096, actual: 4225)
            )
        }
    }

    func testIdentityUsesTopLeftRowMajorCoordinates() throws {
        let filter = try RenderMeshWarp.identity(rows: 2, columns: 2)

        XCTAssertEqual(filter.controlPoints, [
            .init(x: 0, y: 0), .init(x: 1, y: 0),
            .init(x: 0, y: 1), .init(x: 1, y: 1)
        ])
        XCTAssertEqual(filter.resize(input: C7Size(width: 9, height: 7)), C7Size(width: 9, height: 7))
        XCTAssertEqual(filter.renderVertexStride, 4)
        XCTAssertEqual(filter.renderSamplerConsumption, .runtimeBound)
        XCTAssertEqual(
            filter.setupVertices(inputSize: C7Size(width: 9, height: 7)),
            [-1, 1, 0, 0, -1, -1, 0, 1, 1, 1, 1, 0, 1, -1, 1, 1]
        )
    }

    func testMeshRowsAreConnectedWithDegenerateTriangles() throws {
        let filter = try RenderMeshWarp.identity(rows: 3, columns: 3)
        let vertices = try XCTUnwrap(filter.setupVertices(inputSize: C7Size(width: 9, height: 7)))

        XCTAssertEqual(vertices.count, 14 * 4)
        XCTAssertEqual(Array(vertices[20..<24]), Array(vertices[24..<28]))
        XCTAssertEqual(Array(vertices[28..<32]), Array(vertices[32..<36]))
    }

    func testIdentityMeshProducesInputPixelsOnGPU() throws {
        let input = try makeTexture(width: 2, height: 2, pixels: [
            255, 0, 0, 255, 0, 255, 0, 255,
            0, 0, 255, 255, 255, 255, 255, 255
        ])
        let filter = try RenderMeshWarp.identity(rows: 2, columns: 2)
        let output: MTLTexture = try HarbethIO(element: input, filter: filter).output()

        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(output.c7.bytes(), input.c7.bytes())
    }

    private func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
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
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }
}

import XCTest
import Metal
@testable import Harbeth

final class GeometrySamplingTests: XCTestCase {

    func testTransformAdaptiveSamplingAppearsInParameterSummary() {
        let plan = GraphCompiler.compile(
            filters: [
                C7Transform(
                    transform: CGAffineTransform(rotationAngle: .pi / 2),
                    samplingMode: .adaptive
                )
            ],
            inputSize: C7Size(width: 20, height: 10),
            profile: .inspectionQuality
        )

        XCTAssertEqual(plan.diagnostics.nodes.first?.parameterSummary["samplingMode"], "adaptive")
    }

    func testTransformClampEdgeModeKeepsBorderColorWhenSamplingOutOfBounds() throws {
        let input = try makeSolidTexture(red: 255, green: 0, blue: 0, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7Transform(
                transform: CGAffineTransform(translationX: 1, y: 0),
                samplingMode: .nearest,
                edgeMode: .clamp
            )
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 255)
        XCTAssertEqual(pixel.blue, 0)
    }

    func testTransformTransparentEdgeModeReturnsEmptyPixelWhenSamplingOutOfBounds() throws {
        let input = try makeSolidTexture(red: 255, green: 0, blue: 0, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7Transform(
                transform: CGAffineTransform(translationX: 1, y: 0),
                samplingMode: .nearest,
                edgeMode: .transparent
            )
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 0)
        XCTAssertEqual(pixel.green, 0)
        XCTAssertEqual(pixel.blue, 0)
        XCTAssertEqual(pixel.alpha, 0)
    }

    func testCropNearestSamplingPreservesDiscreteTexel() throws {
        let input = try makeHorizontalTwoPixelTexture()
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7Crop(
                origin: C7Point2D(x: 0.25, y: 0),
                width: 1,
                height: 1,
                samplingMode: .nearest
            )
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 255)
        XCTAssertEqual(pixel.blue, 0)
    }

    func testCropLinearSamplingBlendsNeighboringTexels() throws {
        let input = try makeHorizontalTwoPixelTexture()
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7Crop(
                origin: C7Point2D(x: 0.5, y: 0),
                width: 1,
                height: 1,
                samplingMode: .linear
            )
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertGreaterThan(pixel.red, 0)
        XCTAssertGreaterThan(pixel.blue, 0)
        XCTAssertLessThan(pixel.red, 255)
        XCTAssertLessThan(pixel.blue, 255)
        XCTAssertLessThan(abs(Int(pixel.red) - Int(pixel.blue)), 20)
    }

    private func makeHorizontalTwoPixelTexture() throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create geometry fixture texture.")
            throw HarbethError.textureLoader
        }

        let bytes: [UInt8] = [
            255, 0, 0, 255,
            0, 0, 255, 255
        ]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    private func makeSolidTexture(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create geometry fixture texture.")
            throw HarbethError.textureLoader
        }

        let bytes: [UInt8] = [red, green, blue, alpha]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 4
        )
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable RGBA bytes.")
            throw HarbethError.texture2Image
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}

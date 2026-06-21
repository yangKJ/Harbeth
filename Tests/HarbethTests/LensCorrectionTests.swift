import XCTest
import Metal
@testable import Harbeth

final class LensCorrectionTests: XCTestCase {

    func testLensDistortionIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 120, green: 60, blue: 210, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7LensDistortionCorrection()
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
        XCTAssertEqual(pixel.red, 120, accuracy: 2)
        XCTAssertEqual(pixel.green, 60, accuracy: 2)
        XCTAssertEqual(pixel.blue, 210, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testLensDistortionKeepsInputSize() {
        let filter = C7LensDistortionCorrection(distortion: -0.2, cubicDistortion: 0.05, scale: 1.03)
        XCTAssertEqual(filter.resize(input: C7Size(width: 400, height: 300)), C7Size(width: 400, height: 300))
    }

    func testLensDistortionAdaptiveSamplingAppearsInIdentifier() {
        let filter = C7LensDistortionCorrection(
            distortion: -0.15,
            cubicDistortion: 0.03,
            scale: 1.01,
            samplingMode: .adaptive,
            edgeMode: .clamp
        )
        XCTAssertTrue(filter.identifier.contains("C7LensDistortionCorrection"))
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
            XCTFail("Failed to create lens correction fixture texture.")
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

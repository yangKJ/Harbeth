import XCTest
import Metal
@testable import Harbeth

final class ChromaticAberrationTests: XCTestCase {

    func testChromaticAberrationIdentityKeepsSinglePixelVisible() throws {
        let input = try makeSolidTexture(red: 30, green: 180, blue: 240, alpha: 255)
        let output: MTLTexture = try HarbethIO(
            element: input,
            filter: C7ChromaticAberrationCorrection()
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(output.width, 1)
        XCTAssertEqual(output.height, 1)
        XCTAssertEqual(pixel.red, 30, accuracy: 2)
        XCTAssertEqual(pixel.green, 180, accuracy: 2)
        XCTAssertEqual(pixel.blue, 240, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testChromaticAberrationKeepsInputSize() {
        let filter = C7ChromaticAberrationCorrection(
            redCyanShift: -0.02,
            blueYellowShift: 0.015,
            samplingMode: .adaptive,
            edgeMode: .clamp
        )
        XCTAssertEqual(filter.resize(input: C7Size(width: 300, height: 200)), C7Size(width: 300, height: 200))
    }

    func testChromaticAberrationIdentifierContainsTypeName() {
        let filter = C7ChromaticAberrationCorrection(redCyanShift: -0.01, blueYellowShift: 0.01)
        XCTAssertTrue(filter.identifier.contains("C7ChromaticAberrationCorrection"))
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
            XCTFail("Failed to create chromatic aberration fixture texture.")
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

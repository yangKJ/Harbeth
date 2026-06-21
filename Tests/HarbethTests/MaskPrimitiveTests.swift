import XCTest
import Metal
@testable import Harbeth

final class MaskPrimitiveTests: XCTestCase {

    func testMaskBlendUsesMaskOpacity() throws {
        let base = try makeTexture(pixel: [255, 0, 0, 255])
        let effect = try makeTexture(pixel: [0, 0, 255, 255])
        let maskTexture = try makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(effectTexture: effect, mask: descriptor)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 0)
        XCTAssertEqual(pixel.blue, 255)
    }

    func testMaskBlendCanInvertMask() throws {
        let base = try makeTexture(pixel: [255, 0, 0, 255])
        let effect = try makeTexture(pixel: [0, 0, 255, 255])
        let maskTexture = try makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, invert: true, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: base,
            filter: C7MaskRegionBlend(effectTexture: effect, mask: descriptor)
        ).output()

        let pixel = try firstPixel(in: output)
        XCTAssertEqual(pixel.red, 255)
        XCTAssertEqual(pixel.blue, 0)
    }

    private func makeTexture(pixel: [UInt8]) throws -> MTLTexture {
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
            XCTFail("Failed to create texture.")
            throw HarbethError.makeTexture
        }
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: pixel, bytesPerRow: 4)
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

import XCTest
import Metal
import CoreGraphics
@testable import Harbeth

final class AlphaTypeTests: XCTestCase {

    func testCGImageAlphaTypeInferenceRecognizesPremultiplied() throws {
        let image = try makeCGImage(alphaInfo: .premultipliedLast)
        XCTAssertEqual(image.c7.alphaType, .premultiplied)
    }

    func testTextureReadbackCanRequestNonPremultipliedAlphaInfo() throws {
        let texture = try makeSolidTexture(bytes: [64, 128, 255, 128])
        let cgImage = try XCTUnwrap(texture.c7.toCGImage(alphaType: .nonPremultiplied))
        XCTAssertEqual(cgImage.alphaInfo, .last)
    }

    func testPremultiplyAlphaFilterMultipliesRGBByAlpha() throws {
        let texture = try makeSolidTexture(bytes: [200, 100, 50, 128])
        let output: MTLTexture = try HarbethIO(element: texture, filter: C7PremultiplyAlpha()).output()
        let pixel = try firstPixel(in: output)

        XCTAssertEqual(pixel.red, 100, accuracy: 2)
        XCTAssertEqual(pixel.green, 50, accuracy: 2)
        XCTAssertEqual(pixel.blue, 25, accuracy: 2)
        XCTAssertEqual(pixel.alpha, 128, accuracy: 1)
    }

    func testUnpremultiplyAlphaFilterRestoresRGBFromPremultipliedInput() throws {
        let texture = try makeSolidTexture(bytes: [100, 50, 25, 128])
        let output: MTLTexture = try HarbethIO(element: texture, filter: C7UnpremultiplyAlpha()).output()
        let pixel = try firstPixel(in: output)

        XCTAssertEqual(pixel.red, 199, accuracy: 3)
        XCTAssertEqual(pixel.green, 100, accuracy: 3)
        XCTAssertEqual(pixel.blue, 50, accuracy: 3)
        XCTAssertEqual(pixel.alpha, 128, accuracy: 1)
    }

    private func makeCGImage(alphaInfo: CGImageAlphaInfo) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytes = [UInt8](repeating: 255, count: 4)
        let bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: 1,
                                  height: 1,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: 4,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo,
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            throw XCTSkip("Failed to create CGImage fixture.")
        }
        return image
    }

    private func makeSolidTexture(bytes: [UInt8]) throws -> MTLTexture {
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
            throw HarbethError.textureLoader
        }
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: bytes, bytesPerRow: 4)
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            throw HarbethError.texture2Image
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}

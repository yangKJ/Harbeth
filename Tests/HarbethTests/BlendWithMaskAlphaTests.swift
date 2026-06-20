import XCTest
import Metal
@testable import Harbeth

final class BlendWithMaskAlphaTests: XCTestCase {

    func testColorRGBAPreservesAlphaBeforeMaskBlend() throws {
        let input = try makeSolidTexture(red: 200, green: 160, blue: 120, alpha: 255)
        let tinted = try HarbethIO(
            element: input,
            filter: C7ColorRGBA(color: C7Color(hex: 0xD8F0FF, alpha: 0.1), intensity: 1.0)
        ).output()

        let pixel = try firstPixel(in: tinted)

        XCTAssertEqual(pixel.alpha, 255, "C7ColorRGBA 的颜色 alpha 应作为染色强度，不应降低照片本身 alpha")
    }

    func testColorRGBAPreservesRGBIntensityWhenColorAlphaIsLow() throws {
        let input = try makeSolidTexture(red: 200, green: 160, blue: 120, alpha: 255)
        let tinted = try HarbethIO(
            element: input,
            filter: C7ColorRGBA(color: C7Color(hex: 0x000000, alpha: 0.1), intensity: 0.5)
        ).output()

        let pixel = try firstPixel(in: tinted)

        XCTAssertEqual(pixel.red, 100, accuracy: 2, "C7ColorRGBA 的 RGB 强度应由 intensity 控制，不能再被颜色 alpha 二次压弱")
        XCTAssertEqual(pixel.green, 80, accuracy: 2, "低 alpha 颜色仍应保持原有 RGB 混合强度")
        XCTAssertEqual(pixel.blue, 60, accuracy: 2, "低 alpha 颜色仍应保持原有 RGB 混合强度")
        XCTAssertEqual(pixel.alpha, 255, "恢复 RGB 强度时仍必须保持照片 alpha")
    }

    func testBlendWithMaskPreservesBackgroundAlphaWhenForegroundHasLowAlpha() throws {
        let background = try makeSolidTexture(red: 32, green: 64, blue: 96, alpha: 255)
        let foreground = try makeSolidTexture(red: 220, green: 240, blue: 255, alpha: 26)
        let mask = try makeMaskTexture(value: 255)

        let output = try HarbethIO(
            element: background,
            filter: C7BlendWithMask(foregroundTexture: foreground, maskTexture: mask)
        ).output()
        let pixel = try firstPixel(in: output)

        XCTAssertEqual(pixel.alpha, 255, "普通蒙版合成应保持背景 alpha，不能把前景低 alpha 写进最终照片")
        XCTAssertGreaterThan(pixel.red, 32, "全白 mask 应让前景 RGB 生效")
    }

    func testXORBlendWithMaskPreservesBackgroundAlphaWhenForegroundHasLowAlpha() throws {
        let background = try makeSolidTexture(red: 32, green: 64, blue: 96, alpha: 255)
        let foreground = try makeSolidTexture(red: 220, green: 240, blue: 255, alpha: 26)
        let mask = try makeMaskTexture(value: 255)

        let output = try HarbethIO(
            element: background,
            filter: C7XORBlendWithMask(foregroundTexture: foreground, maskTexture: mask)
        ).output()
        let pixel = try firstPixel(in: output)

        XCTAssertEqual(pixel.alpha, 255, "XOR 蒙版合成应保持背景 alpha，不能把前景低 alpha 写进最终照片")
        XCTAssertGreaterThan(pixel.red, 32, "XOR 全白 mask 应让前景 RGB 生效")
    }

    private func makeSolidTexture(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create solid texture.")
            throw HarbethError.textureLoader
        }

        let bytes = Array(repeating: [red, green, blue, alpha], count: 4).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 2),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    private func makeMaskTexture(value: UInt8) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create mask texture.")
            throw HarbethError.textureLoader
        }

        let bytes = Array(repeating: [value, value, value, UInt8(255)], count: 4).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 2),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
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

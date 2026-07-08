import XCTest
import Metal
@testable import Harbeth

/// Mask 测试共享 helper。
///
/// 目的:把 `MaskPrimitiveTests` 与 `MaskedForegroundBlendAlphaTests` 重复的
/// `makeTexture / firstPixel / bytes / makeSolidTexture / makeMaskTexture` 提到一处,
/// 避免未来加 mask 测试时再复制粘贴 setup 代码。
///
/// 设计:全部以 `static` 形式提供,不要让 helper class 进入继承链;
/// 这样 XCTest 不会把这些方法当成"半个测试"统计进测试用例数。
enum MaskTestHelpers {

    // MARK: - Device

    static var device: MTLDevice? {
        MTLCreateSystemDefaultDevice()
    }

    static func requireDevice(file: StaticString = #file, line: UInt = #line) throws -> MTLDevice {
        guard let device = device else {
            throw XCTSkip("Metal device is unavailable.", file: file, line: line)
        }
        return device
    }

    // MARK: - 基础纹理构造

    /// 创建一张 `width × height` 的 rgba8Unorm 纹理,所有像素填充同一组 RGBA。
    static func makeTexture(width: Int = 1,
                            height: Int = 1,
                            red: UInt8 = 0,
                            green: UInt8 = 0,
                            blue: UInt8 = 0,
                            alpha: UInt8 = 255,
                            renderTarget: Bool = false) throws -> MTLTexture {
        let device = try requireDevice()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = renderTarget
            ? [.shaderRead, .shaderWrite, .renderTarget]
            : [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create \(width)x\(height) texture.")
            throw HarbethError.makeTexture
        }
        let pixels = Array(repeating: [red, green, blue, alpha], count: width * height).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    /// 创建一张只填一组 RGBA 的 1×1 纹理(原 `MaskPrimitiveTests.makeTexture(pixel:)` 的语义)。
    static func makeTexture(pixel: [UInt8]) throws -> MTLTexture {
        guard pixel.count == 4 else {
            XCTFail("pixel must be 4 RGBA bytes, got \(pixel.count).")
            throw HarbethError.makeTexture
        }
        return try makeTexture(
            width: 1, height: 1,
            red: pixel[0], green: pixel[1], blue: pixel[2], alpha: pixel[3]
        )
    }

    /// 创建一张 `width × height` 的纯色 mask(原 `MaskedForegroundBlendAlphaTests.makeMaskTexture` 语义)。
    static func makeMaskTexture(width: Int = 2, height: Int = 2, value: UInt8) throws -> MTLTexture {
        try makeTexture(width: width, height: height, red: value, green: value, blue: value, alpha: 255)
    }

    /// 创建一张 `width × height` 的纯色背景(原 `MaskedForegroundBlendAlphaTests.makeSolidTexture` 语义)。
    static func makeSolidTexture(red: UInt8,
                                 green: UInt8,
                                 blue: UInt8,
                                 alpha: UInt8,
                                 width: Int = 2,
                                 height: Int = 2) throws -> MTLTexture {
        try makeTexture(width: width, height: height, red: red, green: green, blue: blue, alpha: alpha)
    }

    // MARK: - 像素读取

    /// 读取整张纹理的全部 RGBA 字节(行优先,与现有 `MaskPrimitiveTests.bytes(in:)` 等价)。
    static func bytes(in texture: MTLTexture) throws -> [UInt8] {
        guard let raw = texture.c7.bytes(), raw.count >= texture.width * texture.height * 4 else {
            XCTFail("Expected readable RGBA bytes from texture \(texture.width)x\(texture.height).")
            throw HarbethError.texture2Image
        }
        return Array(raw)
    }

    /// 读取 (0, 0) 像素的 RGBA(原 `MaskPrimitiveTests.firstPixel(in:)` 语义)。
    static func firstPixel(in texture: MTLTexture) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let raw = try bytes(in: texture)
        return (raw[0], raw[1], raw[2], raw[3])
    }

    /// 读取任意 `(x, y)` 像素的 RGBA(给多像素断言用,例如 feather 渐变)。
    static func pixel(in texture: MTLTexture, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        var buf = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &buf,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return (buf[0], buf[1], buf[2], buf[3])
    }

    /// 创建一张 5×5 的"中心高亮四角全黑"亮度模板,用于 luminance 组件测试。
    ///
    /// 中心 (2,2) = (255, 0, 0)(纯红),其余 (0, 0, 0)(纯黑)。
    /// 这样:
    /// - `.red` 组件在中心 → 1.0,其余 → 0.0
    /// - `.luminance` 组件在中心 → 0.299(Rec.601 R 权重),其余 → 0.0
    /// - `.alpha` 组件在中心 → 1.0,其余 → 1.0(无法区分,只能验证 luminance / red 在中心非零)
    static func makeLuminanceProbeTexture(size: Int = 5) throws -> MTLTexture {
        let device = try requireDevice()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size, height: size,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create \(size)x\(size) luminance probe texture.")
            throw HarbethError.makeTexture
        }
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let center = size / 2
        let offset = (center * size + center) * 4
        pixels[offset + 0] = 255 // red
        pixels[offset + 1] = 0
        pixels[offset + 2] = 0
        pixels[offset + 3] = 255
        // 其余保持 (0,0,0,0) — 但 alpha=0 会让所有 component 路径都读到 0,所以中心以外改为 (0,0,0,255)
        for y in 0..<size {
            for x in 0..<size {
                if x == center && y == center { continue }
                let i = (y * size + x) * 4
                pixels[i + 3] = 255
            }
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, size, size),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: size * 4
        )
        return texture
    }

    static func maskedBlend(background: MTLTexture, foreground: MTLTexture, mask: MaskDescriptor) -> HarbethIO<MTLTexture> {
        HarbethIO(
            element: background,
            filter: MaskRegionBlend(effectTexture: foreground, mask: mask)
        )
    }
}

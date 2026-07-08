import XCTest
import Metal
@testable import Harbeth

final class MaskedForegroundBlendAlphaTests: XCTestCase {

    func testColorRGBAPreservesAlphaBeforeMaskBlend() throws {
        let input = try MaskTestHelpers.makeSolidTexture(red: 200, green: 160, blue: 120, alpha: 255)
        let tinted = try HarbethIO(
            element: input,
            filter: C7ColorRGBA(color: C7Color(hex: 0xD8F0FF, alpha: 0.1), intensity: 1.0)
        ).output()

        let pixel = try MaskTestHelpers.firstPixel(in: tinted)

        XCTAssertEqual(pixel.alpha, 255, "C7ColorRGBA 的颜色 alpha 应作为染色强度，不应降低照片本身 alpha")
    }

    func testColorRGBAPreservesRGBIntensityWhenColorAlphaIsLow() throws {
        let input = try MaskTestHelpers.makeSolidTexture(red: 200, green: 160, blue: 120, alpha: 255)
        let tinted = try HarbethIO(
            element: input,
            filter: C7ColorRGBA(color: C7Color(hex: 0x000000, alpha: 0.1), intensity: 0.5)
        ).output()

        let pixel = try MaskTestHelpers.firstPixel(in: tinted)

        XCTAssertEqual(pixel.red, 100, accuracy: 2, "C7ColorRGBA 的 RGB 强度应由 intensity 控制，不能再被颜色 alpha 二次压弱")
        XCTAssertEqual(pixel.green, 80, accuracy: 2, "低 alpha 颜色仍应保持原有 RGB 混合强度")
        XCTAssertEqual(pixel.blue, 60, accuracy: 2, "低 alpha 颜色仍应保持原有 RGB 混合强度")
        XCTAssertEqual(pixel.alpha, 255, "恢复 RGB 强度时仍必须保持照片 alpha")
    }

    func testMaskedForegroundBlendPreservesBackgroundAlphaWhenForegroundHasLowAlpha() throws {
        let background = try MaskTestHelpers.makeSolidTexture(red: 32, green: 64, blue: 96, alpha: 255)
        let foreground = try MaskTestHelpers.makeSolidTexture(red: 220, green: 240, blue: 255, alpha: 26)
        let mask = try MaskTestHelpers.makeMaskTexture(value: 255)

        let output = try HarbethIO(
            element: background,
            filter: C7MaskedForegroundBlend(foregroundTexture: foreground, maskTexture: mask)
        ).output()
        let pixel = try MaskTestHelpers.firstPixel(in: output)

        XCTAssertEqual(pixel.alpha, 255, "前景蒙版合成应保持背景 alpha，不能把前景低 alpha 写进最终照片")
        XCTAssertGreaterThan(pixel.red, 32, "全白 mask 应让前景 RGB 生效")
    }

    // MARK: - W2 P1 #6:C7MaskedForegroundBlend.intensity 滑条三档

    /// 验证 intensity 真的是强度系数而不是开关:
    /// - 0.0 → 输出 = 背景
    /// - 0.5 → 输出 ≈ mix(背景, 前景, 0.5)
    /// - 1.0 → 输出 = 前景
    func testMaskedForegroundBlendIntensitySliderControlsStrength() throws {
        let background = try MaskTestHelpers.makeSolidTexture(
            red: 0, green: 0, blue: 0, alpha: 255
        )
        let foreground = try MaskTestHelpers.makeSolidTexture(
            red: 255, green: 255, blue: 255, alpha: 255
        )
        let mask = try MaskTestHelpers.makeMaskTexture(value: 255)

        // intensity = 0.0:不应有任何前景渗透
        let zeroOut = try HarbethIO(
            element: background,
            filter: C7MaskedForegroundBlend(
                foregroundTexture: foreground,
                maskTexture: mask,
                intensity: 0.0
            )
        ).output()
        let zeroPixel = try MaskTestHelpers.firstPixel(in: zeroOut)
        XCTAssertEqual(zeroPixel.red, 0, accuracy: 2, "intensity=0 时前景白不应渗透")
        XCTAssertEqual(zeroPixel.green, 0, accuracy: 2, "intensity=0 时前景白不应渗透")
        XCTAssertEqual(zeroPixel.blue, 0, accuracy: 2, "intensity=0 时前景白不应渗透")
        XCTAssertEqual(zeroPixel.alpha, 255, "intensity=0 仍应保持背景 alpha")

        // intensity = 0.5:前景应半透
        let midOut = try HarbethIO(
            element: background,
            filter: C7MaskedForegroundBlend(
                foregroundTexture: foreground,
                maskTexture: mask,
                intensity: 0.5
            )
        ).output()
        let midPixel = try MaskTestHelpers.firstPixel(in: midOut)
        XCTAssertEqual(midPixel.red, 128, accuracy: 8, "intensity=0.5 应让前景 RGB 半透")
        XCTAssertEqual(midPixel.green, 128, accuracy: 8)
        XCTAssertEqual(midPixel.blue, 128, accuracy: 8)
        XCTAssertEqual(midPixel.alpha, 255, "intensity=0.5 仍应保持背景 alpha")

        // intensity = 1.0:前景完全透(已有 alpha 测试覆盖 alpha 行为,这里只补 RGB 兜底)
        let fullOut = try HarbethIO(
            element: background,
            filter: C7MaskedForegroundBlend(
                foregroundTexture: foreground,
                maskTexture: mask,
                intensity: 1.0
            )
        ).output()
        let fullPixel = try MaskTestHelpers.firstPixel(in: fullOut)
        XCTAssertEqual(fullPixel.red, 255, accuracy: 2, "intensity=1.0 时前景白应完全渗透")
        XCTAssertEqual(fullPixel.green, 255, accuracy: 2)
        XCTAssertEqual(fullPixel.blue, 255, accuracy: 2)
    }

}

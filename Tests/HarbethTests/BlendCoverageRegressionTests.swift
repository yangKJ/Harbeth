// 由 Condy 创建于 2026/11/17。
import Metal
import CoreGraphics
import XCTest
@testable import Harbeth

final class BlendCoverageRegressionTests: XCTestCase {
    static let modes: [C7Blend.BlendType] = [.add, .alpha, .colorBurn, .colorDodge, .darken, .darkerColor,
        .difference, .dissolve, .divide, .exclusion, .hardLight, .hardMix, .hue, .lighten, .lighterColor,
        .linearBurn, .linearLight, .luminosity, .mask, .multiply, .normal, .overlay, .pinLight,
        .saturation, .screen, .softLight, .sourceOver, .subtract, .vividLight, .color]

    func testEveryCatalogModeHasExactZeroHDRAndMissingForegroundBypass() throws {
        for format in [MTLPixelFormat.rgba16Float, .rgba32Float] {
            let source = try ColorMathPixels.make(width: 2, height: 1, values: [30000.003, 20000.007, -2.1, 1, 0.13, 0.11, 0.03, 0.25], format: format)
            let bytes = source.c7.rawBytes(maximumBytes: 32)
            for mode in Self.modes {
                for amount: Float in [0, .nan] {
                    let result: MTLTexture = try HarbethIO(element: source, filter: C7Blend(with: mode, blendTexture: source, intensity: amount)).output()
                    XCTAssertEqual(result.c7.rawBytes(maximumBytes: 32), bytes, mode.kernel)
                }
                let result: MTLTexture = try HarbethIO(element: source, filter: C7Blend(with: mode, blendTexture: nil)).output()
                XCTAssertEqual(result.c7.rawBytes(maximumBytes: 32), bytes, mode.kernel)
            }
            let tinyValues: [Float] = [0.001, 0.002, 0.003, 1, 0.001, 0.002, 0.003, 1]
            let tiny = try ColorMathPixels.make(width: 2, height: 1, values: tinyValues, format: format)
            for mode in [C7Blend.BlendType.normal, .sourceOver, .dissolve] {
                let actual: MTLTexture = try HarbethIO(element: source, filter: C7Blend(with: mode, blendTexture: tiny)).output()
                XCTAssertEqual(actual.c7.rawBytes(maximumBytes: 32), tiny.c7.rawBytes(maximumBytes: 32), "\(mode.kernel) 全强度端点")
            }
        }
    }

    func testCatalogTransparentLimitsAndNoResidualColor() throws {
        for format in ColorMathPixels.formats {
            let clear = try pixel([0, 0, 0, 0], format), base = try pixel([0.1, 0.2, 0.05, 0.5], format)
            let b = try ColorMathPixels.read(base)
            for mode in Self.modes {
                XCTAssertEqual(try render(clear, C7Blend(with: mode, blendTexture: clear)), [0, 0, 0, 0], mode.kernel)
                if mode != .mask && mode != .dissolve {
                    ColorMathPixels.assertPixels(try render(base, C7Blend(with: mode, blendTexture: clear)), b, format: format)
                }
                if mode != .mask && mode != .alpha {
                    ColorMathPixels.assertPixels(try render(clear, C7Blend(with: mode, blendTexture: base)), b, format: format)
                }
            }
        }
    }

    func testNormalAndSourceOverUseUnionCoverageAtEveryIntensity() throws {
        for format in ColorMathPixels.formats {
            let base = try pixel([0.1, 0.2, 0.05, 0.5], format), top = try pixel([0.15, 0.025, 0.1, 0.25], format)
            let b = try ColorMathPixels.read(base), s = try ColorMathPixels.read(top)
            for mode in [C7Blend.BlendType.normal, .sourceOver] { for t: Float in [0.25, 0.5, 1] {
                let expected = (0..<4).map { b[$0] * (1 - s[3] * t) + s[$0] * t }
                ColorMathPixels.assertPixels(try render(base, C7Blend(with: mode, blendTexture: top, intensity: t)), expected, format: format)
                let frame = try ImageNode.texture(base).applying(C7Blend(with: mode, blendTexture: top, intensity: t)).makeFrame()
                XCTAssertEqual(frame.alphaType, .premultiplied)
            } }
        }
    }

    func testMaskScalesAllChannelsOnceAndDissolveKeepsCrossfade() throws {
        let base = try pixel([0.2, 0.1, 0.3, 0.5], .rgba32Float)
        let b = try ColorMathPixels.read(base)
        for coverage: Float in [0, 0.25, 1] {
            let mask = try pixel([coverage, coverage, coverage, coverage], .rgba32Float)
            for t: Float in [0.5, 1] {
                ColorMathPixels.assertPixels(try render(base, C7Blend(with: .mask, blendTexture: mask, intensity: t)), b.map { $0 * (1 + t * (coverage - 1)) }, format: .rgba32Float)
                let s = [coverage, coverage, coverage, coverage]
                ColorMathPixels.assertPixels(try render(base, C7Blend(with: .dissolve, blendTexture: mask, intensity: t)), (0..<4).map { b[$0] + (s[$0] - b[$0]) * t }, format: .rgba32Float)
            }
        }
    }

    func testForegroundSamplingUsesPixelCentresForCatalogAndThreeTextureBlend() throws {
        let base = try ColorMathPixels.make(width: 4, height: 1, values: Array(repeating: [Float](arrayLiteral: 0, 0, 0, 1), count: 4).flatMap { $0 }, format: .rgba32Float)
        let values: [Float] = [0, 0, 0, 1, 1.0 / 3, 0, 0, 1, 2.0 / 3, 0, 0, 1, 1, 0, 0, 1]
        let top = try ColorMathPixels.make(width: 4, height: 1, values: values, format: .rgba32Float)
        let mask = try pixel([1, 1, 1, 1], .rgba32Float)
        for filter: any C7FilterProtocol in [C7Blend(with: .normal, blendTexture: top), C7MaskedForegroundBlend(foregroundTexture: top, maskTexture: mask)] {
            ColorMathPixels.assertPixels(try render(base, filter), values, format: .rgba32Float)
        }
        let small = try ColorMathPixels.make(width: 2, height: 1, values: [0, 0, 0, 1, 1, 0, 0, 1], format: .rgba32Float)
        let out = try render(base, C7Blend(with: .sourceOver, blendTexture: small))
        for (x, value) in [Float](arrayLiteral: 0, 0.25, 0.75, 1).enumerated() { XCTAssertEqual(out[x * 4], value, accuracy: 0.00002) }
    }

    func testOpaqueCatalogColorsRetainFrozenBeforeChangeReference() throws {
        let base = try ColorMathPixels.make(width: 2, height: 1, values: [0.2, 0.4, 0.6, 1, 0.9, 0.15, 0.05, 1], format: .rgba16Float)
        let top = try ColorMathPixels.make(width: 2, height: 1, values: [0.7, 0.3, 0.5, 1, 0.1, 0.8, 0.25, 1], format: .rgba16Float)
        for (mode, intensity, expected) in opaqueBlendReference {
            let actual = try render(base, C7Blend(with: mode, blendTexture: top, intensity: intensity))
            for i in expected.indices { XCTAssertEqual(actual[i], expected[i], accuracy: 0.004, "\(mode.kernel) 分量\(i)") }
        }
    }

    func testCGImageMaskFrameContributesNothingOverBlackOrWhite() throws {
        let image = try RGBA8ImageBuffer(width: 1, height: 1, bytes: [128, 0, 0, 128], colorSpace: XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))).makeCGImage()
        let mask = try pixel([0, 0, 0, 1], .rgba16Float)
        let frame = try ImageNode.cgImage(image).applying(C7Blend(with: .mask, blendTexture: mask)).makeFrame(profile: .exportQuality)
        XCTAssertEqual(frame.alphaType, .premultiplied)
        XCTAssertEqual(try ColorMathPixels.read(frame.texture), [0, 0, 0, 0])
        for value: Float in [0, 1] {
            let background = try pixel([value, value, value, 1], .rgba16Float)
            XCTAssertEqual(try render(background, RenderLayerComposite(layerTexture: frame.texture)), [value, value, value, 1])
        }
    }

    private func pixel(_ values: [Float], _ format: MTLPixelFormat) throws -> MTLTexture { try ColorMathPixels.make(width: 1, height: 1, values: values, format: format) }
    private func render(_ source: MTLTexture, _ filter: any C7FilterProtocol) throws -> [Float] {
        let out: MTLTexture = try HarbethIO(element: source, filter: filter).output()
        return try ColorMathPixels.read(out)
    }
}

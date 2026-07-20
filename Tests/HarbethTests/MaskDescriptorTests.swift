//
//  MaskDescriptorTests.swift
//  Harbeth
//

import XCTest
import Metal
@testable import Harbeth

final class MaskDescriptorTests: XCTestCase {

    func testMaskBlendUsesMaskOpacity() throws {
        let base = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let effect = try MaskTestHelpers.makeTexture(pixel: [0, 0, 255, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, opacity: 1)

        let output = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: descriptor)
            .output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 0, "mask alpha=0 应让 effect 蓝完全覆盖 base 红 → R 通道应为 0")
        XCTAssertEqual(pixel.blue, 255, "mask alpha=0 应让 effect 蓝完全覆盖 base 红 → B 通道应为 255")
    }

    func testMaskBlendCanInvertMask() throws {
        let base = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let effect = try MaskTestHelpers.makeTexture(pixel: [0, 0, 255, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, invert: true, opacity: 1)

        let output = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: descriptor)
            .output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 255, "mask invert=true 应让 base 红穿透 → R 通道应回到 255")
        XCTAssertEqual(pixel.blue, 0, "mask invert=true 应让 base 红穿透 → B 通道应回到 0")
    }

    func testMaskBlendRespectsTransparentAndOpaqueOpacity() throws {
        let base = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let effect = try MaskTestHelpers.makeTexture(pixel: [0, 255, 0, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])

        let transparentOutput = try MaskTestHelpers
            .maskedBlend(
                background: base,
                foreground: effect,
                mask: MaskDescriptor(texture: maskTexture, opacity: 0)
            )
            .output()
        let opaqueOutput = try MaskTestHelpers
            .maskedBlend(
                background: base,
                foreground: effect,
                mask: MaskDescriptor(texture: maskTexture, opacity: 1)
            )
            .output()

        XCTAssertEqual(try MaskTestHelpers.firstPixel(in: transparentOutput).red, 255, "opacity=0 时前景应完全不渗透,输出 = base 红")
        XCTAssertEqual(try MaskTestHelpers.firstPixel(in: opaqueOutput).green, 255, "opacity=1 时前景应完全渗透,输出 = effect 绿")
    }

    func testMaskBlendSelectsRequestedColorComponent() throws {
        let base = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let effect = try MaskTestHelpers.makeTexture(pixel: [0, 255, 0, 255])
        let redMask = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 0])
        let greenMask = try MaskTestHelpers.makeTexture(pixel: [0, 255, 0, 0])

        let redOutput = try MaskTestHelpers
            .maskedBlend(
                background: base,
                foreground: effect,
                mask: MaskDescriptor(texture: redMask, component: .red, opacity: 1)
            )
            .output()
        let greenOutput = try MaskTestHelpers
            .maskedBlend(
                background: base,
                foreground: effect,
                mask: MaskDescriptor(texture: greenMask, component: .red, opacity: 1)
            )
            .output()

        XCTAssertEqual(try MaskTestHelpers.firstPixel(in: redOutput).green, 255, ".red component 取 R 通道,R=255 的 mask 应让 effect 绿的 G 通道被 mix 出来")
        XCTAssertEqual(try MaskTestHelpers.firstPixel(in: greenOutput).red, 255, ".red component 取 R 通道,G=255 的 mask R=0 应让 base 红穿透")
    }

    func testMaskBlendAddModeAddsEffectThroughOpaqueMask() throws {
        let base = try MaskTestHelpers.makeTexture(pixel: [100, 50, 25, 255])
        let effect = try MaskTestHelpers.makeTexture(pixel: [80, 100, 120, 128])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, blendMode: .add, opacity: 1)

        let output = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: descriptor)
            .output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 180, accuracy: 2, "add 路径:R=100+80=180,验证通道加法")
        XCTAssertEqual(pixel.green, 150, accuracy: 2, "add 路径:G=50+100=150")
        XCTAssertEqual(pixel.blue, 145, accuracy: 2, "add 路径:B=25+120=145")
        XCTAssertEqual(pixel.alpha, 255, "alpha 通道不应被 mask 影响")
    }

    func testMaskBlendMultiplyModeMultipliesEffectThroughOpaqueMask() throws {
        let base = try MaskTestHelpers.makeTexture(pixel: [100, 50, 25, 255])
        let effect = try MaskTestHelpers.makeTexture(pixel: [80, 100, 120, 128])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, blendMode: .multiply, opacity: 1)

        let output = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: descriptor)
            .output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 31, accuracy: 2, "multiply 路径:R = 100*80/255 ≈ 31,验证通道乘法")
        XCTAssertEqual(pixel.green, 20, accuracy: 2, "multiply 路径:G = 50*100/255 ≈ 20")
        XCTAssertEqual(pixel.blue, 12, accuracy: 2, "multiply 路径:B = 25*120/255 ≈ 12")
        XCTAssertEqual(pixel.alpha, 128, accuracy: 2, "alpha 应保留 effect alpha = 128")
    }

    func testMaskBlendSubtractModeSubtractsEffectThroughOpaqueMask() throws {
        let base = try MaskTestHelpers.makeTexture(pixel: [120, 140, 160, 255])
        let effect = try MaskTestHelpers.makeTexture(pixel: [80, 40, 20, 64])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, blendMode: .subtract, opacity: 1)

        let output = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: descriptor)
            .output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 40, accuracy: 2, "subtract 路径:R = 120-80 = 40,验证通道减法")
        XCTAssertEqual(pixel.green, 100, accuracy: 2, "subtract 路径:G = 140-40 = 100")
        XCTAssertEqual(pixel.blue, 140, accuracy: 2, "subtract 路径:B = 160-20 = 140")
        XCTAssertEqual(pixel.alpha, 191, accuracy: 2, "alpha 通道为 base alpha 255 与 effect alpha 64 的合成")
    }

    func testMaskDescriptorFactorsExposeComponentAndFeather() throws {
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [255, 128, 0, 255])
        let descriptor = MaskDescriptor(
            texture: maskTexture,
            component: .red,
            blendMode: .multiply,
            featherPolicy: .normalized(0.4),
            opacity: 0.75
        )
        let filter = MaskRegionBlend(effectTexture: maskTexture, mask: descriptor)

        XCTAssertEqual(filter.factors[0], 0.75, accuracy: 0.0001)
        XCTAssertEqual(filter.factors[2], Float(MaskComponent.red.rawValue), accuracy: 0.0001)
        XCTAssertEqual(filter.factors[3], Float(MaskBlendMode.multiply.rawValue), accuracy: 0.0001)
        XCTAssertEqual(filter.factors[4], 0.4, accuracy: 0.0001)
    }

    func testImageNodeMaskedEffectCompositeUsesLocalEffectPrimitive() throws {
        let base = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let effect = try MaskTestHelpers.makeTexture(pixel: [0, 0, 255, 255])
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: maskTexture, opacity: 1)

        let output = try ImageNode.texture(base)
            .compositing(effectTexture: effect, mask: descriptor)
            .makeTexture(profile: .stablePreview)
        let pixel = try MaskTestHelpers.firstPixel(in: output)

        XCTAssertEqual(pixel.red, 0)
        XCTAssertEqual(pixel.blue, 255)
        XCTAssertEqual(pixel.alpha, 255)
    }
}

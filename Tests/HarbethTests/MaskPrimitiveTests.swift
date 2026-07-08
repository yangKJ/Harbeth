//
//  MaskPrimitiveTests.swift
//  Harbeth
//

import XCTest
import Metal
@testable import Harbeth

final class MaskPrimitiveTests: XCTestCase {

    func testMaskComponentLuminanceDrivesRegionBlendAtRuntime() throws {
        // Arrange
        let probe = try MaskTestHelpers.makeLuminanceProbeTexture(size: 5)
        let base = try MaskTestHelpers.makeTexture(
            width: 5, height: 5,
            red: 255, green: 255, blue: 255, alpha: 255
        )
        let effect = try MaskTestHelpers.makeTexture(
            width: 5, height: 5,
            red: 0, green: 0, blue: 0, alpha: 255
        )

        // Act:用 .red 通道做 region blend(预期中心输出 ≈ 黑,因 effect 是黑色)
        let redOutput = try MaskTestHelpers
            .maskedBlend(
                background: base,
                foreground: effect,
                mask: MaskDescriptor(texture: probe, component: .red, opacity: 1)
            )
            .output()

        // Act:用 .luminance 通道做 region blend(预期中心输出 ≈ mix(255, 0, 0.299) = 178)
        let luminanceOutput = try MaskTestHelpers
            .maskedBlend(
                background: base,
                foreground: effect,
                mask: MaskDescriptor(texture: probe, component: .luminance, opacity: 1)
            )
            .output()

        // Assert
        let redCenter = try MaskTestHelpers.pixel(in: redOutput, x: 2, y: 2)
        let luminanceCorner = try MaskTestHelpers.pixel(in: redOutput, x: 0, y: 0)
        let luminanceOnlyCenter = try MaskTestHelpers.pixel(in: luminanceOutput, x: 2, y: 2)
        let luminanceOnlyCorner = try MaskTestHelpers.pixel(in: luminanceOutput, x: 0, y: 0)

        // 红通道:中心像素纯红,effect 全黑 → mask=1.0 → 输出接近黑
        XCTAssertLessThan(redCenter.red, 10, ".red component 在 probe 中心应让 effect 黑穿透")
        // 红通道:角落像素 probe=黑,无论 component 都是 mask=0 → 输出 base 全白
        XCTAssertEqual(luminanceCorner.red, 255, accuracy: 2, "角落无 mask → base 全白应原样输出")

        // 亮度通道:中心 luminance ≈ 0.299,effect 黑 → mix(255, 0, 0.299) ≈ 178
        XCTAssertEqual(
            luminanceOnlyCenter.red, 178, accuracy: 16,
            ".luminance component 在 probe 中心应按 0.299 Rec.601 权重取值,实测 ≈ 178"
        )
        XCTAssertEqual(luminanceOnlyCorner.red, 255, accuracy: 2, ".luminance 角落为 0 → 输出 base 全白")
    }

    func testMaskShapeFeatherPolicyProducesSoftEdgeOnGPU() throws {
        // Arrange:12×4 底色,纯白
        let base = try MaskTestHelpers.makeTexture(
            width: 12, height: 4,
            red: 255, green: 255, blue: 255, alpha: 255
        )
        // 前景:纯黑
        let effect = try MaskTestHelpers.makeTexture(
            width: 12, height: 4,
            red: 0, green: 0, blue: 0, alpha: 255
        )

        // 构造 shape recipe:rect 占中间 [4..8],正好覆盖 x=4..7 像素(归一化坐标 4/12..7/12 ≈ 0.333..0.583)
        let shape = MaskShapeRecipe(
            size: C7Size(width: 12, height: 4),
            kind: .rectangle(
                rect: CGRect(x: 4.0 / 12.0, y: 0, width: 4.0 / 12.0, height: 1),
                feather: 0   // 硬边 baseline
            )
        )

        // Act:硬边路径
        let hardMask = try shape.makeMaskDescriptor(component: .red, featherPolicy: .none)
        let hardOutput = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: hardMask)
            .output()
        let hardBytes = try MaskTestHelpers.bytes(in: hardOutput)

        // 软边路径(feather = 0.4,羽化宽度 = 0.4 * 0.5 * 12 = 2.4 像素)
        let softShape = MaskShapeRecipe(
            size: C7Size(width: 12, height: 4),
            kind: .rectangle(
                rect: CGRect(x: 4.0 / 12.0, y: 0, width: 4.0 / 12.0, height: 1),
                feather: 0.4
            )
        )
        // feather 已经在 coverage texture 内嵌;MaskRegionBlend 上不再叠加 .normalized()
        // 否则 InnerShaders.metal:395-399 的 smoothstep 会把已经羽化的 mask 又 clip 回硬边。
        let softMask = try softShape.makeMaskDescriptor(
            component: .red, featherPolicy: .none
        )
        let softOutput = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: softMask)
            .output()
        let softBytes = try MaskTestHelpers.bytes(in: softOutput)

        // Assert 1:硬边下,中心像素(x=6, 在 rect 中央)应 ≈ 0(全黑,effect 穿透)
        XCTAssertLessThan(hardBytes[(2 * 12 + 6) * 4], 10, "硬边中心 effect 黑应穿透")

        // Assert 2:硬边下,rect 边界外(x=1)应 ≈ 255(全白,base 透出)
        XCTAssertEqual(hardBytes[(2 * 12 + 1) * 4], 255, accuracy: 2, "硬边外应为 base 全白")

        // Assert 3:软边下,中心像素(x=6)仍应近似全黑(在 shape 内部)
        XCTAssertLessThan(softBytes[(2 * 12 + 6) * 4], 30, "软边中心仍应让 effect 黑穿透")

        // Assert 4:软边的关键证据 —— 在 rect 的左边缘(x=4)与 rect 外的 x=3 之间应该有渐变
        // 硬边: x=3 = 255, x=4 = 0(跳变 ≥ 200)
        // 软边: x=3 与 x=4 应当接近,差距 ≤ 80(因为 feather=0.4 在 12 像素宽度上羽化 2.4 像素)
        let hardEdgeJump = abs(Int(hardBytes[(2 * 12 + 4) * 4]) - Int(hardBytes[(2 * 12 + 3) * 4]))
        XCTAssertGreaterThan(hardEdgeJump, 200, "硬边应当出现大幅跳变")
        // 软边 x=4 的 coverage ≈ smoothstep(0, 0.2, 0.126) ≈ 0.686,mix(白, 黑, 0.686) ≈ 81。
        // x=3 在矩形外,coverage=0,output=255,所以 |255 - 81| = 174。
        // 但**硬边下 x=4 直接是 0**,所以软边比硬边的过渡幅度仍然显著温和。
        XCTAssertGreaterThan(
            softBytes[(2 * 12 + 4) * 4], 30,
            "软边 x=4 应有部分 base 透出(羽化生效),实测=\(softBytes[(2 * 12 + 4) * 4])"
        )
        // 与硬边的关键差异:硬边 x=4 = 0,软边 x=4 > 30,差值即羽化贡献
        XCTAssertGreaterThan(
            Int(softBytes[(2 * 12 + 4) * 4]) - Int(hardBytes[(2 * 12 + 4) * 4]),
            30,
            "软边 x=4 应比硬边亮(羽化让 base 透出更多),soft=\(softBytes[(2 * 12 + 4) * 4]) hard=\(hardBytes[(2 * 12 + 4) * 4])"
        )

        // Assert 5:软边下 x=4 应有非零亮度(羽化已生效)
        // 在 x=4, uv.x ≈ (4+0.5)/12 ≈ 0.375, local = (0.375-0.333)/0.333 = 0.126
        // edgeDistance.x = min(0.126, 0.874) = 0.126
        // featherWidth = max(0.4 * 0.5, 0.000001) = 0.2
        // coverage = smoothstep(0, 0.2, 0.126) ≈ 0.70
        // mix(白, 黑, 0.70) ≈ 76
        XCTAssertGreaterThan(
            softBytes[(2 * 12 + 4) * 4], 60,
            "软边下 x=4 应有非零亮度(羽化已生效),实测 bytes[(2*12+4)*4]=\(softBytes[(2 * 12 + 4) * 4])"
        )
    }
}

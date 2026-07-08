//
//  MaskFingerprintTests.swift
//  Harbeth
//

import XCTest
import Metal
@testable import Harbeth

final class MaskFingerprintTests: XCTestCase {

    func testMaskCompositeRecipeStepFingerprintTracksNamedOperations() throws {
        let baseMask = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let addMask = try MaskTestHelpers.makeTexture(pixel: [64, 0, 0, 255])
        let subtractMask = try MaskTestHelpers.makeTexture(pixel: [32, 0, 0, 255])
        let recipe = MaskCompositeRecipe(
            baseMask: MaskDescriptor(texture: baseMask),
            steps: [
                MaskCompositeStep(
                    name: "subjectBoost",
                    mask: MaskDescriptor(texture: addMask, component: .red, blendMode: .add, opacity: 0.5)
                ),
                MaskCompositeStep(
                    name: "skySubtract",
                    mask: MaskDescriptor(texture: subtractMask, component: .red, blendMode: .subtract, opacity: 1)
                )
            ]
        )

        XCTAssertEqual(recipe.maskCount, 3)
        XCTAssertEqual(recipe.masks.count, 2)
        let stepFields = recipe.fingerprintFields
        // base segment 在顶层是 `base={base=1,component=0,blend=0,invert=0,opacity=1.0000,feather=0.0}`
        // 我们只断言关键字段存在,避免绑定浮点小数位
        let baseValue = stepFields.first(where: { $0.0 == "base" })?.1 ?? ""
        XCTAssertTrue(baseValue.contains("base=1"))
        // base descriptor 默认 component = .alpha(rawValue=0),默认 blendMode = .mix(rawValue=0)
        XCTAssertTrue(baseValue.contains("component=\(MaskComponent.alpha.rawValue)"))
        XCTAssertTrue(baseValue.contains("blend=\(MaskBlendMode.mix.rawValue)"))
        // steps 段保留完整字符串(含 `||` 和 `,`),由测试在内部继续 split
        let stepsValue = stepFields.first(where: { $0.0 == "steps" })?.1 ?? ""
        XCTAssertTrue(stepsValue.contains("name=subjectBoost"))
        XCTAssertTrue(stepsValue.contains("name=skySubtract"))
        // blend 出现两次:add(rawValue=2) / subtract(rawValue=4)
        let blendValues = stepsValue
            .split(whereSeparator: { $0 == "," || $0 == "|" })
            .compactMap { segment -> String? in
                guard segment.hasPrefix("blend=") else { return nil }
                return String(segment.dropFirst("blend=".count))
            }
        XCTAssertTrue(blendValues.contains("\(MaskBlendMode.add.rawValue)"), "应当存在 add(blend=2) step")
        XCTAssertTrue(blendValues.contains("\(MaskBlendMode.subtract.rawValue)"), "应当存在 subtract(blend=4) step")
    }
}

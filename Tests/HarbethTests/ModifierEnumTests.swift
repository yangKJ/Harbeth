//
//  ModifierEnumTests.swift
//  Harbeth
//
//  覆盖 ModifierEnum.name 在 .blit / .mps case 下的稳定性，
// 防止指纹/缓存命中因 UUID 漂移而失效。
//

import XCTest
import Metal
import MetalPerformanceShaders
@testable import Harbeth

final class ModifierEnumTests: XCTestCase {

    // MARK: - 核心修复：.blit 不再回退到 UUID

    /// 修复前：`ModifierEnum.blit.name` 每次都返回不同的 UUID，
    /// 导致 `RenderGraph.nodeName` / `KernelContract.modifierName` 永远 miss。
    /// 修复后：固定返回 `"blit_"`（带下划线后缀，与 `recipeName` 的 `"blit"` 解耦，
    /// 避免 `RenderGraph.nodeName` 拼接出 `"TypeName.blit.TypeName.blit"` 冗余）。
    func testBlitNameIsStableAcrossRepeatedAccess() {
        let mod = ModifierEnum.blit
        let first = mod.name
        let second = mod.name
        let third = mod.name
        XCTAssertEqual(first, second)
        XCTAssertEqual(second, third)
        XCTAssertEqual(first, "blit_")
        XCTAssertFalse(first.contains("-")) // UUID 形如 "550E8400-..."
    }

    /// 同一 case 构造的两个独立 enum 值，name 必须一致（不依赖实例 identity）。
    func testTwoIndependentBlitInstancesReturnSameName() {
        let a = ModifierEnum.blit
        let b = ModifierEnum.blit
        XCTAssertEqual(a.name, b.name)
    }

    // MARK: - 核心修复：.mps(performance:) label 为 nil 时回退到稳定字符串

    /// MPS kernel 默认 label 为 nil（如 MPSImageBox、MPSImageGaussianBlur 等）。
    /// 修复前会回退到 `UUID().uuidString` → 永远不等。
    /// 修复后回退到稳定的类型名，既不漂移，也不会把不同 MPS kernel 折叠成同一个名字。
    func testMPSNameWithoutLabelIsStable() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Metal device is unavailable in this environment.")

        // 两个独立的 MPSImageBox 实例，互不相同
        let kernel1 = MPSImageBox(device: device, kernelWidth: 3, kernelHeight: 3)
        let kernel2 = MPSImageBox(device: device, kernelWidth: 5, kernelHeight: 5)
        XCTAssertNil(kernel1.label)
        XCTAssertNil(kernel2.label)

        let mod1 = ModifierEnum.mps(performance: kernel1)
        let mod2 = ModifierEnum.mps(performance: kernel2)

        // 核心断言：两个独立 kernel 实例得到的 modifier.name 必须相等
        XCTAssertEqual(mod1.name, mod2.name)
        XCTAssertEqual(mod1.name, "MPSImageBox")

        // 再次访问仍稳定
        XCTAssertEqual(mod1.name, mod1.name)
    }

    /// 不同的 unlabeled MPS kernel 不能因为统一 fallback 而发生名字碰撞。
    func testDifferentUnlabeledMPSTypesRemainDistinguishable() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Metal device is unavailable in this environment.")

        let box = MPSImageBox(device: device, kernelWidth: 3, kernelHeight: 3)
        let blur = MPSImageGaussianBlur(device: device, sigma: 1.5)
        XCTAssertNil(box.label)
        XCTAssertNil(blur.label)

        XCTAssertEqual(ModifierEnum.mps(performance: box).name, "MPSImageBox")
        XCTAssertEqual(ModifierEnum.mps(performance: blur).name, "MPSImageGaussianBlur")
        XCTAssertNotEqual(ModifierEnum.mps(performance: box).name, ModifierEnum.mps(performance: blur).name)
    }

    /// 若 MPSKernel 显式设置了 label，则 modifier.name 必须使用该 label，
    /// 保证能在不同 MPS filter 类型之间区分。
    func testMPSNameWithExplicitLabelUsesLabel() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Metal device is unavailable in this environment.")

        let kernel = MPSImageBox(device: device, kernelWidth: 3, kernelHeight: 3)
        kernel.label = "customMPSKernel"

        let mod = ModifierEnum.mps(performance: kernel)
        XCTAssertEqual(mod.name, "customMPSKernel")
    }

    // MARK: - 控制组：确保修复不破坏其它 case 的既有行为

    func testComputeNameIsUnchanged() {
        let mod = ModifierEnum.compute(kernel: "C7Brightness")
        XCTAssertEqual(mod.name, "C7Brightness")
    }

    func testRenderNameIsUnchanged() {
        let mod = ModifierEnum.render(vertex: "harbeth_vertex", fragment: "harbeth_fragment")
        XCTAssertEqual(mod.name, "harbeth_vertex_harbeth_fragment")
    }

    func testMetalCommandNameUsesItsDiagnosticLabel() {
        let mod = ModifierEnum.metalCommand(label: "harbeth_command")
        XCTAssertEqual(mod.name, "harbeth_command")
    }

    // MARK: - 核心合同保护：recipeName 在所有 case 下行为不变

    /// `recipeName` 与 `name` 是两条独立 contract，前者用于 filter recipe 级别的指纹，
    /// 后者用于 encoder 级别。修复 `name` 不能影响 `recipeName`。
    func testRecipeNameIsUnchangedAcrossAllCases() {
        XCTAssertEqual(ModifierEnum.blit.recipeName, "blit")
        XCTAssertEqual(ModifierEnum.compute(kernel: "X").recipeName, "compute:X")
        XCTAssertEqual(ModifierEnum.render(vertex: "v", fragment: "f").recipeName, "render:v|f")
        XCTAssertEqual(ModifierEnum.metalCommand(label: "X").recipeName, "metalCommand:X")
    }

    // MARK: - 行为分离：name 与 recipeName 是两条 contract，不应重复

    /// 关键 contract 解耦验证：
    /// - `name` 用作 encoder 级别指纹（如 `"blit_"` / `"MPSImageBox"`），
    ///   给 `RenderGraph.nodeName` 拼前缀；
    /// - `recipeName` 用作 recipe 级别指纹（无后缀，如 `"blit"` / `"mps"`），
    ///   给 filter recipe 区分。
    /// 两条 contract 不能混用，否则 `RenderGraph.nodeName` 会拼出
    /// `"TypeName.blit.TypeName.blit"` 这种带重复片段的字符串。
    func testBlitNameAndRecipeNameAreDistinctContracts() {
        let mod = ModifierEnum.blit
        XCTAssertEqual(mod.name, "blit_")
        XCTAssertEqual(mod.recipeName, "blit")
        XCTAssertNotEqual(mod.name, mod.recipeName, "name 与 recipeName 必须能区分，避免 RenderGraph.nodeName 拼出重复片段")
    }
}

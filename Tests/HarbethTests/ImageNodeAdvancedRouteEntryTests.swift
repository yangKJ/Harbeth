//
//  ImageNodeAdvancedRouteEntryTests.swift
//  Harbeth
//
//  覆盖 ImageNode 上两条新增的实例链对称入口：
//   - `node.applying(transition:)`
//   - `node.applying(layerComposite:)`
//
// 这些入口是 plan P0#7「API 对称性」的纯加法补齐，行为必须与现有 static 入口
// (`ImageNode.transition(_:)` / `ImageNode.layerComposite(_:)`) 完全一致。
//

import XCTest
import Metal
@testable import Harbeth

final class ImageNodeAdvancedRouteEntryTests: XCTestCase {

    // MARK: - `applying(transition:)` 与 `ImageNode.transition(_:)` 行为一致

    /// 验证 `node.applying(transition:)` 的 5 条证据链行为与 static 入口构造的完全一致。
    /// 这是 plan 第 8 节「统一验收」第一项「输出语义不漂移」的硬约束。
    func testApplyingTransitionMatchesStaticEntryAcrossAllFiveEvidenceChains() throws {
        let from = try makeSolidTexture(width: 3, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeSolidTexture(width: 3, height: 2, pixel: [0, 0, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5,
            profile: .stablePreview
        )

        let staticNode = ImageNode.transition(recipe)
        // 用任意 source node 链式调用，验证 self 被忽略（不污染 storage）
        let chainedNode = ImageNode
            .texture(from)
            .applying(C7Brightness(brightness: 0.1))
            .applying(transition: recipe)

        // 证据链 1/5: makeTexture — 输出一致
        let staticTexture = try staticNode.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        let chainedTexture = try chainedNode.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        XCTAssertEqual(staticTexture.width, chainedTexture.width)
        XCTAssertEqual(staticTexture.height, chainedTexture.height)
        XCTAssertEqual(staticTexture.width, 3)
        XCTAssertEqual(staticTexture.height, 2)

        // 证据链 2/5: makeFrame — metadata / profile / output size 一致
        let staticFrame = try staticNode.makeFrame(profile: recipe.profile, derivative: recipe.derivative, metadata: ["k": "v"])
        let chainedFrame = try chainedNode.makeFrame(profile: recipe.profile, derivative: recipe.derivative, metadata: ["k": "v"])
        XCTAssertEqual(staticFrame.metadata["k"], chainedFrame.metadata["k"])
        XCTAssertEqual(staticFrame.profile, chainedFrame.profile)
        XCTAssertEqual(staticFrame.resolvedOutputSize, chainedFrame.resolvedOutputSize)

        // 证据链 3/5: makeRenderRequest — compilationSource 必须都是 .transition
        let staticRequest = try staticNode.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
        let chainedRequest = try chainedNode.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
        XCTAssertEqual(staticRequest.compilationSource, chainedRequest.compilationSource)
        XCTAssertEqual(staticRequest.compilationSource == .transition, true)
        XCTAssertEqual(chainedRequest.compilationSource == .transition, true)

        // 证据链 4/5: makeRenderRecipe — source / filters 一致
        let staticRenderRecipe = try XCTUnwrap(staticRequest.renderRecipe)
        let chainedRenderRecipe = try XCTUnwrap(chainedRequest.renderRecipe)
        XCTAssertEqual(staticRenderRecipe.source, chainedRenderRecipe.source)
        XCTAssertEqual(staticRenderRecipe.filters.count, chainedRenderRecipe.filters.count)
        XCTAssertEqual(staticRenderRecipe.filters.count, 1)
        XCTAssertEqual(chainedRenderRecipe.filters.count, 1)

        // 证据链 5/5: makeDebugSnapshot — snapshot 输出在两条路径上保持一致
        let staticSnapshot = try staticNode.makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)
        let chainedSnapshot = try chainedNode.makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)
        XCTAssertEqual(staticSnapshot.renderRecipe?.source, chainedSnapshot.renderRecipe?.source)
        XCTAssertEqual(staticSnapshot.renderRecipe?.filters.count, chainedSnapshot.renderRecipe?.filters.count)
    }

    /// 验证实例链写法不会引入第三条公开路线：
    /// 不论前置 self 是 source / filters，最终 compilationSource 都必须是 .transition。
    func testApplyingTransitionIgnoresInputAndStaysSourceLikeRecipe() throws {
        let from = try makeSolidTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeSolidTexture(width: 2, height: 2, pixel: [0, 255, 0, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 1
        )

        // 两种不同的前置 self，最终 compilationSource 都必须是 .transition
        let fromSourceNode = ImageNode.texture(from).applying(transition: recipe)
        let filteredNode = ImageNode.texture(from)
            .applying(C7Brightness(brightness: 0.2))
            .applying(transition: recipe)

        let req1 = try fromSourceNode.makeRenderRequest()
        let req2 = try filteredNode.makeRenderRequest()

        XCTAssertEqual(req1.compilationSource == .transition, true)
        XCTAssertEqual(req2.compilationSource == .transition, true)
    }

    // MARK: - `applying(layerComposite:)` 与 `ImageNode.layerComposite(_:)` 行为一致

    /// 验证 `node.applying(layerComposite:)` 的 5 条证据链行为与 static 入口构造的完全一致。
    func testApplyingLayerCompositeMatchesStaticEntryAcrossAllFiveEvidenceChains() throws {
        let background = try makeSolidTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeSolidTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))]
        )

        let staticNode = ImageNode.layerComposite(recipe)
        let chainedNode = ImageNode
            .texture(background)
            .applying(C7Brightness(brightness: 0.1))
            .applying(layerComposite: recipe)

        // 证据链 1/5: makeTexture
        let staticTexture = try staticNode.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        let chainedTexture = try chainedNode.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
        XCTAssertEqual(staticTexture.width, chainedTexture.width)
        XCTAssertEqual(staticTexture.height, chainedTexture.height)
        XCTAssertEqual(staticTexture.width, 2)
        XCTAssertEqual(staticTexture.height, 2)

        // 证据链 2/5: makeFrame
        let staticFrame = try staticNode.makeFrame(profile: recipe.profile, derivative: recipe.derivative, metadata: ["route": "layerComposite"])
        let chainedFrame = try chainedNode.makeFrame(profile: recipe.profile, derivative: recipe.derivative, metadata: ["route": "layerComposite"])
        XCTAssertEqual(staticFrame.metadata["route"], chainedFrame.metadata["route"])
        XCTAssertEqual(staticFrame.profile, chainedFrame.profile)
        XCTAssertEqual(staticFrame.resolvedOutputSize, chainedFrame.resolvedOutputSize)

        // 证据链 3/5: makeRenderRequest
        let staticRequest = try staticNode.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
        let chainedRequest = try chainedNode.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
        XCTAssertEqual(staticRequest.compilationSource, chainedRequest.compilationSource)
        XCTAssertEqual(staticRequest.compilationSource == .layerComposite, true)
        XCTAssertEqual(chainedRequest.compilationSource == .layerComposite, true)

        // 证据链 4/5: makeRenderRecipe — source 一致
        let staticRenderRecipe = try XCTUnwrap(staticRequest.renderRecipe)
        let chainedRenderRecipe = try XCTUnwrap(chainedRequest.renderRecipe)
        XCTAssertEqual(staticRenderRecipe.source, chainedRenderRecipe.source)
        XCTAssertEqual(staticRenderRecipe.source.kind, "texture")

        // 证据链 5/5: makeDebugSnapshot — snapshot 输出在两条路径上保持一致
        let staticSnapshot = try staticNode.makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)
        let chainedSnapshot = try chainedNode.makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)
        XCTAssertEqual(staticSnapshot.renderRecipe?.source, chainedSnapshot.renderRecipe?.source)
        XCTAssertEqual(staticSnapshot.summary.contains("origin=texture"), chainedSnapshot.summary.contains("origin=texture"))
    }

    /// 验证 layerComposite 实例链不引入第三条公开路线：所有前置 self 都被忽略。
    func testApplyingLayerCompositeIgnoresInputAndStaysSourceLikeRecipe() throws {
        let background = try makeSolidTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeSolidTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1))]
        )

        let fromSourceNode = ImageNode.texture(background).applying(layerComposite: recipe)
        let filteredNode = ImageNode.texture(background)
            .applying(C7Brightness(brightness: 0.2))
            .applying(layerComposite: recipe)

        let req1 = try fromSourceNode.makeRenderRequest()
        let req2 = try filteredNode.makeRenderRequest()

        XCTAssertEqual(req1.compilationSource == .layerComposite, true)
        XCTAssertEqual(req2.compilationSource == .layerComposite, true)
    }

    // MARK: - 行为一致：实例链与 `applying(pluginOutput:)` 在相同 case 下行为一致

    /// 现有 `applying(pluginOutput:)` 在 `.layerComposite(let recipe)` case 下
    /// 忽略 input 并返回 `ImageNode.layerComposite(recipe)`。
    /// 新加的 `applying(layerComposite:)` 必须与这个既有路径完全等价。
    func testApplyingLayerCompositeMatchesExistingPluginOutputPath() throws {
        let background = try makeSolidTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeSolidTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1))]
        )

        let sourceNode = ImageNode.texture(background)

        // 既有路径
        let pluginNode = try sourceNode.applying(pluginOutput: .layerComposite(recipe))
        // 新路径
        let chainedNode = sourceNode.applying(layerComposite: recipe)

        let pluginRequest = try pluginNode.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)
        let chainedRequest = try chainedNode.makeRenderRequest(profile: recipe.profile, derivative: recipe.derivative)

        XCTAssertEqual(pluginRequest.compilationSource, chainedRequest.compilationSource)
        XCTAssertEqual(pluginRequest.source, chainedRequest.source)
    }

    // MARK: - 测试 helper

    private func makeSolidTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Metal device is unavailable.")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor), "Failed to create texture.")
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = 4 * width
        var pixels = [UInt8]()
        for _ in 0..<(width * height) {
            pixels.append(contentsOf: pixel)
        }
        pixels.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }
        return texture
    }
}
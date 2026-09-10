//
//  RenderLayerComposite.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import CoreGraphics
import Foundation
import Metal

/// 使用 Render fixed-function blending 合成一个 premultiplied-alpha 图层。
///
/// 该类型是轻量单层 source-over 原子。复杂 blend、mask、corner 和可编程合成
/// 继续通过 `LayerCompositeRecipe` 使用完整编辑合同。
public struct RenderLayerComposite: RenderProtocol {

    public let layerTexture: MTLTexture
    public let normalizedFrame: CGRect
    public let opacity: Float

    public var modifier: ModifierEnum {
        .render(vertex: "renderLayerCompositeVertex", fragment: "renderLayerCompositeFragment")
    }

    public var otherInputTextures: C7InputTextures { [layerTexture] }
    public var memoryAccessPattern: MemoryAccessPattern { .multiTexture }
    public var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }
    public var renderBlendMode: RenderBlendMode { .premultipliedSourceOver }
    public var renderPreloadsSourceTexture: Bool { true }
    public var destinationTextureContract: FilterDestinationTextureContract {
        FilterDestinationTextureContract(aliasingPolicy: .inPlaceAllowed)
    }
    public var renderOutputContract: RenderOutputContract {
        RenderOutputContract(inputAlphaExpectation: .premultiplied, alpha: .premultiplied)
    }

    public init(layerTexture: MTLTexture, normalizedFrame: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), opacity: Float = 1) throws {
        let frame = normalizedFrame.standardized
        guard frame.origin.x.isFinite, frame.origin.y.isFinite, frame.width.isFinite, frame.height.isFinite else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderLayerComposite", reason: "normalized frame is non-finite"
            )
        }
        guard frame.width > 0, frame.height > 0 else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderLayerComposite", reason: "normalized frame is empty"
            )
        }
        self.layerTexture = layerTexture
        self.normalizedFrame = frame
        self.opacity = min(max(opacity, 0), 1)
    }

    public var factors: [Float] { [opacity] }

    public func setupVertices(inputSize: C7Size) -> [Float]? {
        let left = Float(normalizedFrame.minX) * 2 - 1
        let right = Float(normalizedFrame.maxX) * 2 - 1
        let top = 1 - Float(normalizedFrame.minY) * 2
        let bottom = 1 - Float(normalizedFrame.maxY) * 2
        return [
            left, bottom, 0, 1,
            right, bottom, 1, 1,
            left, top, 0, 0,
            right, top, 1, 0
        ]
    }
}

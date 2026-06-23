//
//  MaskFilters.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation
import Metal

/// `ImageNode.editing(...)` 路线内部使用的参数化 mask 生成 primitive。
///
/// 这组类型属于执行层，不作为普通用户公开 API 暴露。
struct GradientMask: C7FilterProtocol {
    let kind: MaskGradientKind

    init(kind: MaskGradientKind) {
        self.kind = kind
    }

    var modifier: ModifierEnum {
        .compute(kernel: "InnerGradientMask")
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    var factors: [Float] {
        switch kind {
        case .linear(let startPoint, let endPoint):
            return [
                0,
                Float(startPoint.x),
                Float(startPoint.y),
                Float(endPoint.x),
                Float(endPoint.y),
                0,
                0
            ]
        case .radial(let center, let startRadius, let endRadius):
            return [
                1,
                Float(center.x),
                Float(center.y),
                0,
                0,
                startRadius,
                endRadius
            ]
        }
    }
}

struct ShapeMask: C7FilterProtocol {
    let kind: MaskShapeKind

    init(kind: MaskShapeKind) {
        self.kind = kind
    }

    var modifier: ModifierEnum {
        .compute(kernel: "InnerShapeMask")
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    var factors: [Float] {
        switch kind {
        case .rectangle(let rect, let feather):
            return [
                0,
                Float(rect.origin.x),
                Float(rect.origin.y),
                Float(rect.width),
                Float(rect.height),
                min(max(feather, 0), 1)
            ]
        case .ellipse(let rect, let feather):
            return [
                1,
                Float(rect.origin.x),
                Float(rect.origin.y),
                Float(rect.width),
                Float(rect.height),
                min(max(feather, 0), 1)
            ]
        }
    }
}

struct MaskRegionBlend: C7FilterProtocol {
    let effectTexture: MTLTexture
    let mask: MaskDescriptor

    init(effectTexture: MTLTexture, mask: MaskDescriptor) {
        self.effectTexture = effectTexture
        self.mask = mask
    }

    var modifier: ModifierEnum {
        .compute(kernel: "InnerMaskRegionBlend")
    }

    var factors: [Float] {
        [
            mask.opacity,
            mask.invert ? 1 : 0,
            Float(mask.component.rawValue),
            Float(mask.blendMode.rawValue),
            mask.featherPolicy.amount
        ]
    }

    var otherInputTextures: C7InputTextures {
        [effectTexture, mask.texture]
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}

/// 把任意 `MaskDescriptor` 规范化成 coverage texture。
struct MaskCoverageExtract: C7FilterProtocol {
    let mask: MaskDescriptor

    init(mask: MaskDescriptor) {
        self.mask = mask
    }

    var modifier: ModifierEnum {
        .compute(kernel: "InnerMaskCoverageExtract")
    }

    var factors: [Float] {
        [
            mask.opacity,
            mask.invert ? 1 : 0,
            Float(mask.component.rawValue),
            mask.featherPolicy.amount
        ]
    }
}

/// 组合已有 coverage texture 与额外 mask，输出新的 coverage texture。
struct MaskCoverageBlend: C7FilterProtocol {
    var baseComponent: MaskComponent
    var baseInvert: Bool
    var baseFeatherPolicy: MaskFeatherPolicy
    var baseOpacity: Float
    let mask: MaskDescriptor

    init(baseComponent: MaskComponent = .alpha,
         baseInvert: Bool = false,
         baseFeatherPolicy: MaskFeatherPolicy = .none,
         baseOpacity: Float = 1.0,
         mask: MaskDescriptor) {
        self.baseComponent = baseComponent
        self.baseInvert = baseInvert
        self.baseFeatherPolicy = baseFeatherPolicy
        self.baseOpacity = min(max(baseOpacity, 0), 1)
        self.mask = mask
    }

    var modifier: ModifierEnum {
        .compute(kernel: "InnerMaskCoverageBlend")
    }

    var factors: [Float] {
        [
            baseOpacity,
            baseInvert ? 1 : 0,
            Float(baseComponent.rawValue),
            baseFeatherPolicy.amount,
            mask.opacity,
            mask.invert ? 1 : 0,
            Float(mask.component.rawValue),
            Float(mask.blendMode.rawValue),
            mask.featherPolicy.amount
        ]
    }

    var otherInputTextures: C7InputTextures {
        [mask.texture]
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}

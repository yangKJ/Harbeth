//
//  MaskFilters.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal

/// 新 editing / ImageNode 路线里的参数化 mask 生成 primitive。
///
/// 这一组类型和 `Sources/Compute/Blend Modes/` 的旧 blend-with-mask catalog 不在同一抽象层：
/// - 这里服务 `MaskDescriptor`、`LocalEffectRecipe`、`MaskCompositeRecipe`、`LayerCompositeRecipe`
/// - 那边服务“直接拿几张 texture 做一次混合”的旧滤镜目录
public struct C7GradientMask: C7FilterProtocol {
    public let kind: MaskGradientKind

    public init(kind: MaskGradientKind) {
        self.kind = kind
    }

    public var modifier: ModifierEnum {
        .compute(kernel: "C7GradientMask")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var factors: [Float] {
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

public struct C7ShapeMask: C7FilterProtocol {
    public let kind: MaskShapeKind

    public init(kind: MaskShapeKind) {
        self.kind = kind
    }

    public var modifier: ModifierEnum {
        .compute(kernel: "C7ShapeMask")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var factors: [Float] {
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

public struct C7MaskRegionBlend: C7FilterProtocol {
    public let effectTexture: MTLTexture
    public let mask: MaskDescriptor

    public init(effectTexture: MTLTexture, mask: MaskDescriptor) {
        self.effectTexture = effectTexture
        self.mask = mask
    }

    public var modifier: ModifierEnum {
        .compute(kernel: "C7MaskRegionBlend")
    }

    public var factors: [Float] {
        [
            mask.opacity,
            mask.invert ? 1 : 0,
            Float(mask.component.rawValue),
            Float(mask.blendMode.rawValue),
            mask.featherPolicy.amount
        ]
    }

    public var otherInputTextures: C7InputTextures {
        [effectTexture, mask.texture]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}

/// 把任意 `MaskDescriptor` 规范化成 coverage texture。
///
/// 输出为灰度 coverage surface：
/// - RGB 写入相同 coverage 值
/// - alpha 固定为 1
/// - 可作为后续 `C7MaskCoverageBlend` / `C7MaskRegionBlend` / layer mask 的统一输入
public struct C7MaskCoverageExtract: C7FilterProtocol {
    public let mask: MaskDescriptor

    public init(mask: MaskDescriptor) {
        self.mask = mask
    }

    public var modifier: ModifierEnum {
        .compute(kernel: "C7MaskCoverageExtract")
    }

    public var factors: [Float] {
        [
            mask.opacity,
            mask.invert ? 1 : 0,
            Float(mask.component.rawValue),
            mask.featherPolicy.amount
        ]
    }
}

/// 组合已有 coverage texture 与额外 mask，输出新的 coverage texture。
///
/// 这层 primitive 保持 Harbeth 轻量：
/// - 输入仍然只是 texture + mask descriptor
/// - 不引入 selection stack / editor state
/// - 但能承接 add / subtract / multiply 这类局部选择组合语义
public struct C7MaskCoverageBlend: C7FilterProtocol {
    public var baseComponent: MaskComponent
    public var baseInvert: Bool
    public var baseFeatherPolicy: MaskFeatherPolicy
    public var baseOpacity: Float
    public let mask: MaskDescriptor

    public init(baseComponent: MaskComponent = .alpha,
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

    public var modifier: ModifierEnum {
        .compute(kernel: "C7MaskCoverageBlend")
    }

    public var factors: [Float] {
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

    public var otherInputTextures: C7InputTextures {
        [mask.texture]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}

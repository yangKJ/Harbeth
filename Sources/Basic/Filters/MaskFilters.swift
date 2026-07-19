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

    var kernelParameterBindings: [KernelParameterBinding] {
        [KernelParameterBinding(name: "parameters", index: 0, stage: .compute, value: .floatArray(parameters))]
    }

    private var parameters: [Float] {
        var values = [Float](repeating: 0, count: 28)
        switch kind {
        case .linear(let startPoint, let endPoint):
            values[0] = 0
            values[1] = Float(startPoint.x); values[2] = Float(startPoint.y)
            values[3] = Float(endPoint.x); values[4] = Float(endPoint.y)
        case .radial(let center, let startRadius, let endRadius):
            values[0] = 1
            values[1] = Float(center.x); values[2] = Float(center.y)
            values[5] = startRadius; values[6] = endRadius
        case .angular(let center, let startAngle, let endAngle, let clockwise):
            values[0] = 2
            values[1] = Float(center.x); values[2] = Float(center.y)
            values[5] = startAngle; values[6] = endAngle; values[7] = clockwise ? 1 : 0
        case .diamond(let center, let startRadius, let endRadius):
            values[0] = 3
            values[1] = Float(center.x); values[2] = Float(center.y)
            values[5] = startRadius; values[6] = endRadius
        case .reflected(let centerPoint, let edgePoint):
            values[0] = 4
            values[1] = Float(centerPoint.x); values[2] = Float(centerPoint.y)
            values[3] = Float(edgePoint.x); values[4] = Float(edgePoint.y)
        case .band(let startPoint, let endPoint, let halfWidth, let softness):
            values[0] = 5
            values[1] = Float(startPoint.x); values[2] = Float(startPoint.y)
            values[3] = Float(endPoint.x); values[4] = Float(endPoint.y)
            values[5] = max(halfWidth, 0); values[6] = min(max(softness, 0), 1)
        case .ring(let center, let innerRadius, let peakRadius, let outerRadius):
            values[0] = 6
            values[1] = Float(center.x); values[2] = Float(center.y)
            values[5] = innerRadius; values[6] = peakRadius; values[7] = outerRadius
        case .multiStopLinear(let startPoint, let endPoint, _, let curve):
            values[0] = 7
            values[1] = Float(startPoint.x); values[2] = Float(startPoint.y)
            values[3] = Float(endPoint.x); values[4] = Float(endPoint.y)
            values[8] = curve.shaderValue
            let stops = kind.normalizedStops
            values[9] = Float(stops.count)
            for (index, stop) in stops.enumerated() {
                values[10 + index * 2] = stop.location
                values[11 + index * 2] = stop.coverage
            }
        }
        return values
    }
}

struct ShapeMask: C7FilterProtocol {
    let kind: MaskShapeKind
    let transform: MaskPathTransform

    init(kind: MaskShapeKind, transform: MaskPathTransform = .identity) {
        self.kind = kind
        self.transform = transform
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
                min(max(feather, 0), 1),
                0
            ]
            + transformFactors
        case .ellipse(let rect, let feather):
            return [
                1,
                Float(rect.origin.x),
                Float(rect.origin.y),
                Float(rect.width),
                Float(rect.height),
                min(max(feather, 0), 1),
                0
            ]
            + transformFactors
        case .roundedRect(let rect, let cornerRadius, let feather):
            return [
                2,
                Float(rect.origin.x),
                Float(rect.origin.y),
                Float(rect.width),
                Float(rect.height),
                min(max(feather, 0), 1),
                min(max(cornerRadius, 0), 0.5)
            ]
            + transformFactors
        case .regularPolygon, .star:
            preconditionFailure("regularPolygon/star should be lowered to PathMask before execution.")
        }
    }

    private var transformFactors: [Float] {
        [
            Float(transform.translation.x),
            Float(transform.translation.y),
            Float(transform.scale.x),
            Float(transform.scale.y),
            Float(transform.rotationRadians),
            Float(transform.anchor.x),
            Float(transform.anchor.y),
            Float(transform.rotationAspectRatio)
        ]
    }
}

struct PathMask: C7FilterProtocol {
    let recipe: MaskPathRecipe
    let feather: Float

    init(recipe: MaskPathRecipe, feather: Float = 0) {
        self.recipe = recipe
        self.feather = max(feather, 0)
    }

    var modifier: ModifierEnum {
        .compute(kernel: "InnerPathMask")
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        let encoded = recipe.encodedPath()
        let metadata: [Float] = [
            Float(encoded.points.count),
            Float(encoded.ranges.count),
            recipe.fillRule == .evenOdd ? 1 : 0,
            feather
        ]
        let pointValues = encoded.points.flatMap { [Float($0.x), Float($0.y)] }
        let rangeValues = encoded.ranges.flatMap { [$0.x, $0.y] }
        return [
            KernelParameterBinding(name: "metadata", index: 0, stage: .compute, value: .floatArray(metadata)),
            KernelParameterBinding(name: "points", index: 1, stage: .compute, value: .floatArray(pointValues)),
            KernelParameterBinding(name: "ranges", index: 2, stage: .compute, value: .floatArray(rangeValues))
        ]
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

/// 一次按顺序融合最多四个 coverage，避免布尔图谱为每层生成中间纹理。
struct MaskCoverageBlendBatch: C7FilterProtocol {
    var baseComponent: MaskComponent
    var baseInvert: Bool
    var baseFeatherPolicy: MaskFeatherPolicy
    var baseOpacity: Float
    let masks: [MaskDescriptor]

    init(baseComponent: MaskComponent = .alpha,
         baseInvert: Bool = false,
         baseFeatherPolicy: MaskFeatherPolicy = .none,
         baseOpacity: Float = 1,
         masks: [MaskDescriptor]) {
        self.baseComponent = baseComponent
        self.baseInvert = baseInvert
        self.baseFeatherPolicy = baseFeatherPolicy
        self.baseOpacity = min(max(baseOpacity, 0), 1)
        self.masks = Array(masks.prefix(4))
    }

    var modifier: ModifierEnum {
        .compute(kernel: "InnerMaskCoverageBlendBatch4")
    }

    var factors: [Float] {
        var values: [Float] = [
            baseOpacity,
            baseInvert ? 1 : 0,
            Float(baseComponent.rawValue),
            baseFeatherPolicy.amount,
            Float(masks.count)
        ]
        for index in 0..<4 {
            if index < masks.count {
                let mask = masks[index]
                values.append(contentsOf: [
                    mask.opacity,
                    mask.invert ? 1 : 0,
                    Float(mask.component.rawValue),
                    Float(mask.blendMode.rawValue),
                    mask.featherPolicy.amount
                ])
            } else {
                values.append(contentsOf: [0, 0, Float(MaskComponent.red.rawValue), Float(MaskBlendMode.add.rawValue), 0])
            }
        }
        return values
    }

    var otherInputTextures: C7InputTextures {
        guard let fallback = masks.last?.texture else { return [] }
        var textures = masks.map(\.texture)
        while textures.count < 4 { textures.append(fallback) }
        return textures
    }

    var memoryAccessPattern: MemoryAccessPattern { .multiTexture }
}

struct MaskDistanceField: C7FilterProtocol {
    let maxDistance: Float
    let threshold: Float

    var modifier: ModifierEnum {
        .compute(kernel: "MaskDistanceField")
    }

    var factors: [Float] {
        [maxDistance, threshold]
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    var samplingFootprint: SamplingFootprint {
        .dynamic
    }
}

struct BrushMask: C7FilterProtocol {
    let points: [MaskBrushPoint]
    let settings: MaskBrushSettings

    var modifier: ModifierEnum { .compute(kernel: "InnerBrushMask") }
    var memoryAccessPattern: MemoryAccessPattern { .point }

    var kernelParameterBindings: [KernelParameterBinding] {
        let metadata: [Float] = [
            Float(points.count), settings.width, settings.hardness,
            settings.spacing, settings.mode == .erase ? 1 : 0
        ]
        let values = points.reduce(into: [Float]()) { result, point in
            result.append(contentsOf: [Float(point.point.x), Float(point.point.y), point.pressure, 0])
        }
        return [
            KernelParameterBinding(name: "metadata", index: 0, stage: .compute, value: .floatArray(metadata)),
            KernelParameterBinding(name: "points", index: 1, stage: .compute, value: .floatArray(values))
        ]
    }
}

struct RangeMask: C7FilterProtocol {
    let kind: MaskRangeKind

    var modifier: ModifierEnum { .compute(kernel: "InnerRangeMask") }
    var memoryAccessPattern: MemoryAccessPattern { .point }
    var kernelParameterBindings: [KernelParameterBinding] {
        [KernelParameterBinding(name: "parameters", index: 0, stage: .compute, value: .floatArray(kind.shaderParameters))]
    }
}

struct MaskPointThreshold: C7FilterProtocol {
    let threshold: Float
    var modifier: ModifierEnum { .compute(kernel: "InnerMaskPointThreshold") }
    var factors: [Float] { [min(max(threshold, 0), 1)] }
    var memoryAccessPattern: MemoryAccessPattern { .point }
}

struct MaskEdgeCleanup: C7FilterProtocol {
    let blackPoint: Float
    let whitePoint: Float
    var modifier: ModifierEnum { .compute(kernel: "InnerMaskEdgeCleanup") }
    var factors: [Float] { [min(max(blackPoint, 0), 1), min(max(whitePoint, 0), 1)] }
    var memoryAccessPattern: MemoryAccessPattern { .point }
}

struct MaskEdgeAwareFeather: C7FilterProtocol {
    let guideTexture: MTLTexture
    let radius: Int
    let edgeSensitivity: Float
    var modifier: ModifierEnum { .compute(kernel: "InnerMaskEdgeAwareFeather") }
    var factors: [Float] { [Float(min(max(radius, 1), 12)), min(max(edgeSensitivity, 0), 1)] }
    var otherInputTextures: C7InputTextures { [guideTexture] }
    var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
    var samplingFootprint: SamplingFootprint { .neighborhood(radius: min(max(radius, 1), 12)) }
}

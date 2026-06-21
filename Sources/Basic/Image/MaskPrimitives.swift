//
//  MaskPrimitives.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public enum MaskComponent: Int, Sendable, Codable, Equatable, Hashable {
    case alpha = 0
    case red = 1
    case green = 2
    case blue = 3
    case luminance = 4
}

public enum MaskBlendMode: Int, Sendable, Codable, Equatable, Hashable {
    case mix = 0
    case replace = 1
    case add = 2
    case multiply = 3
    case subtract = 4
}

public enum MaskFeatherPolicy: Sendable, Codable, Equatable, Hashable {
    case none
    case normalized(Float)

    var amount: Float {
        switch self {
        case .none:
            return 0
        case .normalized(let value):
            return min(max(value, 0), 1)
        }
    }
}

public struct MaskDescriptor {
    public let texture: MTLTexture
    public var component: MaskComponent
    public var blendMode: MaskBlendMode
    public var invert: Bool
    public var featherPolicy: MaskFeatherPolicy
    public var opacity: Float

    public init(texture: MTLTexture,
                component: MaskComponent = .alpha,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0) {
        self.texture = texture
        self.component = component
        self.blendMode = blendMode
        self.invert = invert
        self.featherPolicy = featherPolicy
        self.opacity = min(max(opacity, 0), 1)
    }
}

public struct LocalEffectRecipe {
    public var filters: [C7FilterProtocol]
    public var mask: MaskDescriptor
    public var maskRecipe: MaskCompositeRecipe?

    public init(filters: [C7FilterProtocol], mask: MaskDescriptor) {
        self.filters = filters
        self.mask = mask
        self.maskRecipe = nil
    }

    public init(filters: [C7FilterProtocol], maskRecipe: MaskCompositeRecipe) {
        self.filters = filters
        self.mask = maskRecipe.baseMask
        self.maskRecipe = maskRecipe
    }

    func resolvedMaskDescriptor() throws -> MaskDescriptor {
        if let maskRecipe {
            return try maskRecipe.makeMaskDescriptor()
        }
        return mask
    }

    public var recipeDescriptor: LocalEffectRecipeDescriptor {
        LocalEffectRecipeDescriptor(
            filters: filters.map(\.recipeDescriptor),
            mask: (maskRecipe?.graphDescriptor) ?? mask.graphDescriptor
        )
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

public struct MaskCompositeStep {
    public var name: String
    public var mask: MaskDescriptor

    public init(name: String = "mask", mask: MaskDescriptor) {
        self.name = name
        self.mask = mask
    }

    public var fingerprint: String {
        [
            "name=\(name)",
            "component=\(mask.component.rawValue)",
            "blend=\(mask.blendMode.rawValue)",
            "invert=\(mask.invert ? 1 : 0)",
            "opacity=\(String(format: "%.4f", mask.opacity))",
            "feather=\(mask.featherPolicy.amount)"
        ].joined(separator: ",")
    }

    public var descriptor: MaskCompositeStepDescriptor {
        MaskCompositeStepDescriptor(
            name: name,
            component: mask.component,
            blendMode: mask.blendMode,
            invert: mask.invert,
            opacity: mask.opacity,
            featherAmount: mask.featherPolicy.amount
        )
    }
}

public struct MaskCompositeRecipe {
    public var baseMask: MaskDescriptor
    public var steps: [MaskCompositeStep]
    public var profile: RenderProfile

    public init(baseMask: MaskDescriptor,
                masks: [MaskDescriptor] = [],
                profile: RenderProfile = .stablePreview) {
        self.baseMask = baseMask
        self.steps = masks.enumerated().map { index, mask in
            MaskCompositeStep(name: "mask\(index)", mask: mask)
        }
        self.profile = profile
    }

    public init(baseMask: MaskDescriptor,
                steps: [MaskCompositeStep],
                profile: RenderProfile = .stablePreview) {
        self.baseMask = baseMask
        self.steps = steps
        self.profile = profile
    }

    public var maskCount: Int {
        1 + steps.count
    }

    public var masks: [MaskDescriptor] {
        steps.map(\.mask)
    }

    public var fingerprint: String {
        let baseSegment = [
            "base=1",
            "component=\(baseMask.component.rawValue)",
            "blend=\(baseMask.blendMode.rawValue)",
            "invert=\(baseMask.invert ? 1 : 0)",
            "opacity=\(String(format: "%.4f", baseMask.opacity))",
            "feather=\(baseMask.featherPolicy.amount)"
        ].joined(separator: ",")
        return [
            "profile=\(profile)",
            "base={\(baseSegment)}",
            "steps=\(steps.isEmpty ? "none" : steps.map(\.fingerprint).joined(separator: "||"))"
        ].joined(separator: "|")
    }

    public var graphDescriptor: MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskCompositeRecipe",
            fingerprint: fingerprint,
            component: baseMask.component,
            blendMode: baseMask.blendMode,
            invert: baseMask.invert,
            opacity: baseMask.opacity,
            featherAmount: baseMask.featherPolicy.amount,
            stepCount: steps.count,
            steps: steps.map(\.descriptor)
        )
    }

    public func makeTexture() throws -> MTLTexture {
        var current = try HarbethIO(
            element: baseMask.texture,
            filter: C7MaskCoverageExtract(mask: baseMask)
        )
        .configured(for: profile)
        .output()

        for step in steps {
            current = try HarbethIO(
                element: current,
                filter: C7MaskCoverageBlend(baseComponent: .red, mask: step.mask)
            )
            .configured(for: profile)
            .output()
        }
        return current
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   opacity: Float = 1.0) throws -> MaskDescriptor {
        MaskDescriptor(
            texture: try makeTexture(),
            component: component,
            blendMode: blendMode,
            opacity: opacity
        )
    }
}

extension MaskDescriptor {
    public var graphDescriptor: MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskDescriptor",
            fingerprint: [
                "component=\(component.rawValue)",
                "blend=\(blendMode.rawValue)",
                "invert=\(invert ? 1 : 0)",
                "opacity=\(String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), opacity))",
                "feather=\(String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), featherPolicy.amount))"
            ].joined(separator: ","),
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: opacity,
            featherAmount: featherPolicy.amount,
            stepCount: 0,
            steps: []
        )
    }
}

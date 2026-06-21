//
//  MaskPrimitives.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
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

    public init(filters: [C7FilterProtocol], mask: MaskDescriptor) {
        self.filters = filters
        self.mask = mask
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

//
//  LayerCompositeRecipe.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import CoreGraphics
import Metal

public enum LayerBlendMode: Int, Sendable, Codable, Equatable, Hashable {
    case normal = 0
    case sourceOver = 1
    case add = 2
    case multiply = 3
    case screen = 4
}

public struct ImageLayer {
    public var content: HarbethSource
    public var filters: [C7FilterProtocol]
    public var normalizedFrame: CGRect
    public var opacity: Float
    public var blendMode: LayerBlendMode
    public var transform: ImageTransformRecipe
    public var mask: MaskDescriptor?
    public var compositingMask: MaskDescriptor?
    public var cornerRadius: Float

    public init(content: HarbethSource,
                filters: [C7FilterProtocol] = [],
                normalizedFrame: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                opacity: Float = 1,
                blendMode: LayerBlendMode = .sourceOver,
                transform: ImageTransformRecipe = ImageTransformRecipe(),
                mask: MaskDescriptor? = nil,
                compositingMask: MaskDescriptor? = nil,
                cornerRadius: Float = 0) {
        self.content = content
        self.filters = filters
        self.normalizedFrame = normalizedFrame.standardized
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
        self.transform = transform
        self.mask = mask
        self.compositingMask = compositingMask
        self.cornerRadius = max(cornerRadius, 0)
    }
}

public struct LayerCompositeRecipe {
    public var background: HarbethSource
    public var layers: [ImageLayer]
    public var profile: RenderProfile
    public var derivative: ImageDerivativeSpec
    public var outputContract: RenderOutputContract

    public init(background: HarbethSource,
                layers: [ImageLayer],
                profile: RenderProfile = .stablePreview,
                derivative: ImageDerivativeSpec? = nil,
                outputContract: RenderOutputContract = .preserveInput) {
        self.background = background
        self.layers = layers
        self.profile = profile
        self.derivative = derivative ?? profile.defaultDerivativeSpec
        self.outputContract = outputContract
    }

    public var layerCount: Int {
        layers.count
    }
}

public struct C7LayerComposite: C7FilterProtocol {
    public let layerTexture: MTLTexture
    public let mask: MaskDescriptor?
    public let compositingMask: MaskDescriptor?
    public let normalizedFrame: CGRect
    public let opacity: Float
    public let blendMode: LayerBlendMode
    public let cornerRadius: Float

    public init(layerTexture: MTLTexture,
                mask: MaskDescriptor? = nil,
                compositingMask: MaskDescriptor? = nil,
                normalizedFrame: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                opacity: Float = 1,
                blendMode: LayerBlendMode = .sourceOver,
                cornerRadius: Float = 0) {
        self.layerTexture = layerTexture
        self.mask = mask
        self.compositingMask = compositingMask
        self.normalizedFrame = normalizedFrame.standardized
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
        self.cornerRadius = max(cornerRadius, 0)
    }

    public var modifier: ModifierEnum {
        .compute(kernel: "C7LayerComposite")
    }

    public var factors: [Float] {
        [
            Float(normalizedFrame.origin.x),
            Float(normalizedFrame.origin.y),
            Float(normalizedFrame.size.width),
            Float(normalizedFrame.size.height),
            opacity,
            Float(blendMode.rawValue),
            mask == nil ? 0 : 1,
            Float(mask?.component.rawValue ?? MaskComponent.alpha.rawValue),
            mask?.invert == true ? 1 : 0,
            compositingMask == nil ? 0 : 1,
            Float(compositingMask?.component.rawValue ?? MaskComponent.alpha.rawValue),
            compositingMask?.invert == true ? 1 : 0,
            cornerRadius
        ]
    }

    public var otherInputTextures: C7InputTextures {
        [
            layerTexture,
            mask?.texture ?? layerTexture,
            compositingMask?.texture ?? layerTexture
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }
}

//
//  LayerCompositeFilter.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import CoreGraphics
import Metal

public struct C7LayerComposite: C7FilterProtocol {
    public let layerTexture: MTLTexture
    public let mask: MaskDescriptor?
    public let compositingMask: MaskDescriptor?
    public let normalizedFrame: CGRect
    public let contentRegion: CGRect
    public let opacity: Float
    public let blendMode: LayerBlendMode
    public let cornerRadius: Float
    public let cornerCurve: LayerCornerCurve
    public let tintColor: SIMD4<Float>?

    public init(layerTexture: MTLTexture,
                mask: MaskDescriptor? = nil,
                compositingMask: MaskDescriptor? = nil,
                normalizedFrame: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                contentRegion: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                opacity: Float = 1,
                blendMode: LayerBlendMode = .sourceOver,
                cornerRadius: Float = 0,
                cornerCurve: LayerCornerCurve = .circular,
                tintColor: SIMD4<Float>? = nil) {
        self.layerTexture = layerTexture
        self.mask = mask
        self.compositingMask = compositingMask
        self.normalizedFrame = normalizedFrame.standardized
        self.contentRegion = contentRegion.standardized
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
        self.cornerRadius = max(cornerRadius, 0)
        self.cornerCurve = cornerCurve
        self.tintColor = tintColor
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
            Float(contentRegion.origin.x),
            Float(contentRegion.origin.y),
            Float(contentRegion.size.width),
            Float(contentRegion.size.height),
            opacity,
            Float(blendMode.rawValue),
            mask == nil ? 0 : 1,
            Float(mask?.component.rawValue ?? MaskComponent.alpha.rawValue),
            Float(mask?.blendMode.rawValue ?? MaskBlendMode.mix.rawValue),
            mask?.invert == true ? 1 : 0,
            mask?.opacity ?? 1,
            mask?.featherPolicy.amount ?? 0,
            compositingMask == nil ? 0 : 1,
            Float(compositingMask?.component.rawValue ?? MaskComponent.alpha.rawValue),
            Float(compositingMask?.blendMode.rawValue ?? MaskBlendMode.mix.rawValue),
            compositingMask?.invert == true ? 1 : 0,
            compositingMask?.opacity ?? 1,
            compositingMask?.featherPolicy.amount ?? 0,
            cornerRadius,
            cornerCurve == .continuous ? 1 : 0,
            tintColor?.x ?? 0,
            tintColor?.y ?? 0,
            tintColor?.z ?? 0,
            tintColor?.w ?? 0,
            tintColor == nil ? 0 : 1
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

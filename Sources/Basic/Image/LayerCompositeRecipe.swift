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
    case overlay = 5
    case darken = 6
    case lighten = 7
    case difference = 8
    case subtract = 9
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
        self.normalizedFrame = ImageLayer.clampedNormalizedFrame(normalizedFrame)
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
        self.transform = transform
        self.mask = mask
        self.compositingMask = compositingMask
        self.cornerRadius = max(cornerRadius, 0)
    }

    public var hasMask: Bool {
        mask != nil || compositingMask != nil
    }

    public var fingerprint: String {
        [
            "frame=\(String(format: "%.4f", normalizedFrame.origin.x)),\(String(format: "%.4f", normalizedFrame.origin.y)),\(String(format: "%.4f", normalizedFrame.width)),\(String(format: "%.4f", normalizedFrame.height))",
            "opacity=\(String(format: "%.4f", opacity))",
            "blend=\(blendMode.rawValue)",
            "transform=\(transform.fingerprint)",
            "filters=\(filters.isEmpty ? "none" : filters.chainRecipe.fingerprint)",
            "mask=\(mask == nil ? 0 : 1)",
            "compositingMask=\(compositingMask == nil ? 0 : 1)",
            "corner=\(String(format: "%.4f", cornerRadius))"
        ].joined(separator: "|")
    }

    private static func clampedNormalizedFrame(_ rect: CGRect) -> CGRect {
        let standardized = rect.standardized
        let x = min(max(standardized.origin.x, 0), 1)
        let y = min(max(standardized.origin.y, 0), 1)
        let width = min(max(standardized.width, 0), 1 - x)
        let height = min(max(standardized.height, 0), 1 - y)
        return CGRect(x: x, y: y, width: width, height: height)
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

    public var fingerprint: String {
        [
            "layers=\(layers.map(\.fingerprint).joined(separator: "||"))",
            "profile=\(profile)",
            "derivative=\(derivative.name)",
            outputContract.fingerprint
        ].joined(separator: "|")
    }

    public func makeNode() -> HarbethImageNode {
        .layerComposite(self)
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

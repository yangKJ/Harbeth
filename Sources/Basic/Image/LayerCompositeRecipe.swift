//
//  LayerCompositeRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
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
    case colorDodge = 10
    case colorBurn = 11
    case softLight = 12
    case hardLight = 13
    case exclusion = 14
}

public enum LayerLayoutUnit: String, Sendable, Codable, Equatable, Hashable {
    case normalized
    case pixel
}

public enum LayerCornerCurve: String, Sendable, Codable, Equatable, Hashable {
    case circular
    case continuous
}

public struct LayerFlipOptions: Sendable, Codable, Equatable, Hashable {
    public var horizontal: Bool
    public var vertical: Bool

    public init(horizontal: Bool = false, vertical: Bool = false) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public var fingerprint: String {
        "h=\(horizontal ? 1 : 0)|v=\(vertical ? 1 : 0)"
    }
}

public struct ImageLayer {
    public var content: ImageSource
    public var filters: [C7FilterProtocol]
    public var normalizedFrame: CGRect
    public var contentRegion: CGRect
    public var layoutUnit: LayerLayoutUnit
    public var opacity: Float
    public var blendMode: LayerBlendMode
    public var transform: ImageTransformRecipe
    public var flipOptions: LayerFlipOptions
    public var rotation: Float
    public var tintColor: SIMD4<Float>?
    public var mask: MaskDescriptor?
    public var compositingMask: MaskDescriptor?
    public var cornerRadius: Float
    public var cornerCurve: LayerCornerCurve
    public var rasterSampleCount: Int

    public init(content: ImageSource,
                filters: [C7FilterProtocol] = [],
                normalizedFrame: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                contentRegion: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                layoutUnit: LayerLayoutUnit = .normalized,
                opacity: Float = 1,
                blendMode: LayerBlendMode = .sourceOver,
                transform: ImageTransformRecipe = ImageTransformRecipe(),
                flipOptions: LayerFlipOptions = LayerFlipOptions(),
                rotation: Float = 0,
                tintColor: SIMD4<Float>? = nil,
                mask: MaskDescriptor? = nil,
                compositingMask: MaskDescriptor? = nil,
                cornerRadius: Float = 0,
                cornerCurve: LayerCornerCurve = .circular,
                rasterSampleCount: Int = 1) {
        self.content = content
        self.filters = filters
        self.normalizedFrame = ImageLayer.clampedNormalizedFrame(normalizedFrame)
        self.contentRegion = ImageLayer.clampedNormalizedFrame(contentRegion)
        self.layoutUnit = layoutUnit
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
        self.transform = transform
        self.flipOptions = flipOptions
        self.rotation = rotation
        self.tintColor = tintColor
        self.mask = mask
        self.compositingMask = compositingMask
        self.cornerRadius = max(cornerRadius, 0)
        self.cornerCurve = cornerCurve
        self.rasterSampleCount = max(rasterSampleCount, 1)
    }

    public var hasMask: Bool {
        mask != nil || compositingMask != nil
    }

    public var fingerprint: String {
        [
            "frame=\(String(format: "%.4f", normalizedFrame.origin.x)),\(String(format: "%.4f", normalizedFrame.origin.y)),\(String(format: "%.4f", normalizedFrame.width)),\(String(format: "%.4f", normalizedFrame.height))",
            "contentRegion=\(String(format: "%.4f", contentRegion.origin.x)),\(String(format: "%.4f", contentRegion.origin.y)),\(String(format: "%.4f", contentRegion.width)),\(String(format: "%.4f", contentRegion.height))",
            "layout=\(layoutUnit.rawValue)",
            "opacity=\(String(format: "%.4f", opacity))",
            "blend=\(blendMode.rawValue)",
            "transform=\(transform.fingerprint)",
            "flip=\(flipOptions.fingerprint)",
            "rotation=\(String(format: "%.4f", rotation))",
            "tint=\(tintColor.map { "\($0.x),\($0.y),\($0.z),\($0.w)" } ?? "none")",
            "filters=\(filters.isEmpty ? "none" : filters.chainRecipe.fingerprint)",
            "mask=\(mask == nil ? 0 : 1)",
            "compositingMask=\(compositingMask == nil ? 0 : 1)",
            "corner=\(String(format: "%.4f", cornerRadius))",
            "cornerCurve=\(cornerCurve.rawValue)",
            "samples=\(rasterSampleCount)"
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
    public var background: ImageSource
    public var layers: [ImageLayer]
    public var profile: RenderProfile
    public var derivative: ImageDerivativeSpec
    public var outputContract: RenderOutputContract

    public init(background: ImageSource,
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

    public func makeNode() -> ImageNode {
        .layerComposite(self)
    }

    public func makeRenderRequest(derivative: ImageDerivativeSpec? = nil) throws -> RenderRequest {
        let effectiveDerivative = derivative ?? self.derivative
        let node = makeNode()
        let diagnostics = try node.makeDiagnostics(profile: profile, derivative: effectiveDerivative)
        let recipeDescriptor = try node.makeRenderRecipe(profile: profile, derivative: effectiveDerivative)
        return RenderRequest(
            compilationSource: .layerComposite,
            profile: profile,
            derivative: effectiveDerivative,
            source: background.descriptor,
            outputCachePolicy: .transient,
            diagnostics: diagnostics,
            renderRecipe: recipeDescriptor,
            renderTexture: { try makeTexture(derivative: effectiveDerivative) },
            renderFrame: { metadata in
                try node.makeFrame(profile: profile, derivative: effectiveDerivative, metadata: metadata)
            }
        )
    }
}

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
            mask?.invert == true ? 1 : 0,
            compositingMask == nil ? 0 : 1,
            Float(compositingMask?.component.rawValue ?? MaskComponent.alpha.rawValue),
            compositingMask?.invert == true ? 1 : 0,
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

//
//  FilterRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

private func stableRecipeFloatDescription(_ value: Float) -> String {
    String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
}

public struct FilterRecipeDescriptor: Sendable, Hashable, Codable {
    public let stableTypeID: String
    public let modifier: String
    public let parameterValues: [String]
    public let otherInputTextureCount: Int
    public let hasCount: Bool

    public init(stableTypeID: String,
                modifier: String,
                parameterValues: [String],
                otherInputTextureCount: Int,
                hasCount: Bool) {
        self.stableTypeID = stableTypeID
        self.modifier = modifier
        self.parameterValues = parameterValues
        self.otherInputTextureCount = otherInputTextureCount
        self.hasCount = hasCount
    }

    public var fingerprint: String {
        [
            stableTypeID,
            modifier,
            parameterValues.joined(separator: ","),
            "inputs=\(otherInputTextureCount)",
            "count=\(hasCount ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public struct FilterChainRecipe: Sendable, Hashable, Codable {
    public let filters: [FilterRecipeDescriptor]

    public init(filters: [FilterRecipeDescriptor]) {
        self.filters = filters
    }

    public var fingerprint: String {
        filters.map(\.fingerprint).joined(separator: " -> ")
    }
}

public struct MaskCompositeStepDescriptor: Sendable, Hashable, Codable {
    public let name: String
    public let component: MaskComponent
    public let blendMode: MaskBlendMode
    public let invert: Bool
    public let opacity: Float
    public let featherAmount: Float
    public let gradient: MaskGradientDescriptor?
    public let shape: MaskShapeDescriptor?

    public init(name: String,
                component: MaskComponent,
                blendMode: MaskBlendMode,
                invert: Bool,
                opacity: Float,
                featherAmount: Float,
                gradient: MaskGradientDescriptor? = nil,
                shape: MaskShapeDescriptor? = nil) {
        self.name = name
        self.component = component
        self.blendMode = blendMode
        self.invert = invert
        self.opacity = opacity
        self.featherAmount = featherAmount
        self.gradient = gradient
        self.shape = shape
    }

    public var fingerprint: String {
        var parts = [
            "name=\(name)",
            "component=\(component.rawValue)",
            "blend=\(blendMode.rawValue)",
            "invert=\(invert ? 1 : 0)",
            "opacity=\(stableRecipeFloatDescription(opacity))",
            "feather=\(stableRecipeFloatDescription(featherAmount))"
        ]
        if let gradient {
            parts.append("gradient=\(gradient.fingerprint)")
        }
        if let shape {
            parts.append("shape=\(shape.fingerprint)")
        }
        return parts.joined(separator: ",")
    }
}

public struct MaskGradientDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let fingerprint: String
    public let parameterValues: [String]

    public init(kind: String,
                fingerprint: String,
                parameterValues: [String]) {
        self.kind = kind
        self.fingerprint = fingerprint
        self.parameterValues = parameterValues
    }
}

public struct MaskShapeDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let fingerprint: String
    public let parameterValues: [String]

    public init(kind: String,
                fingerprint: String,
                parameterValues: [String]) {
        self.kind = kind
        self.fingerprint = fingerprint
        self.parameterValues = parameterValues
    }
}

public struct MaskGraphDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let fingerprint: String
    public let component: MaskComponent
    public let blendMode: MaskBlendMode
    public let invert: Bool
    public let opacity: Float
    public let featherAmount: Float
    public let stepCount: Int
    public let steps: [MaskCompositeStepDescriptor]
    public let gradient: MaskGradientDescriptor?
    public let shape: MaskShapeDescriptor?

    public init(kind: String,
                fingerprint: String,
                component: MaskComponent,
                blendMode: MaskBlendMode,
                invert: Bool,
                opacity: Float,
                featherAmount: Float,
                stepCount: Int,
                steps: [MaskCompositeStepDescriptor],
                gradient: MaskGradientDescriptor? = nil,
                shape: MaskShapeDescriptor? = nil) {
        self.kind = kind
        self.fingerprint = fingerprint
        self.component = component
        self.blendMode = blendMode
        self.invert = invert
        self.opacity = opacity
        self.featherAmount = featherAmount
        self.stepCount = stepCount
        self.steps = steps
        self.gradient = gradient
        self.shape = shape
    }
}

public struct LocalEffectRecipeDescriptor: Sendable, Hashable, Codable {
    public let filters: [FilterRecipeDescriptor]
    public let mask: MaskGraphDescriptor

    public init(filters: [FilterRecipeDescriptor], mask: MaskGraphDescriptor) {
        self.filters = filters
        self.mask = mask
    }
}

public struct LayerMaskRecipeDescriptor: Sendable, Hashable, Codable {
    public let layerIndex: Int
    public let mask: MaskGraphDescriptor?
    public let compositingMask: MaskGraphDescriptor?

    public init(layerIndex: Int,
                mask: MaskGraphDescriptor?,
                compositingMask: MaskGraphDescriptor?) {
        self.layerIndex = layerIndex
        self.mask = mask
        self.compositingMask = compositingMask
    }
}

public struct RenderRecipe: Sendable, Hashable, Codable {
    public let renderProfile: String
    public let renderIntent: RenderIntent
    public let source: ImageSourceDescriptor
    public let outputDerivative: ImageDerivativeSpec
    public let outputCachePolicy: ImageCachePolicy
    public let outputSemantic: ImageSemanticDescriptor
    public let alphaType: AlphaType
    public let orientation: FrameOrientation
    public let filters: [FilterRecipeDescriptor]
    public let localEffects: [LocalEffectRecipeDescriptor]?
    public let layerMasks: [LayerMaskRecipeDescriptor]?

    public init(renderProfile: String,
                renderIntent: RenderIntent,
                source: ImageSourceDescriptor,
                outputDerivative: ImageDerivativeSpec,
                outputCachePolicy: ImageCachePolicy,
                outputSemantic: ImageSemanticDescriptor,
                alphaType: AlphaType,
                orientation: FrameOrientation,
                filters: [FilterRecipeDescriptor],
                localEffects: [LocalEffectRecipeDescriptor]? = nil,
                layerMasks: [LayerMaskRecipeDescriptor]? = nil) {
        self.renderProfile = renderProfile
        self.renderIntent = renderIntent
        self.source = source
        self.outputDerivative = outputDerivative
        self.outputCachePolicy = outputCachePolicy
        self.outputSemantic = outputSemantic
        self.alphaType = alphaType
        self.orientation = orientation
        self.filters = filters
        self.localEffects = localEffects
        self.layerMasks = layerMasks
    }

    public var fingerprint: String {
        let localEffectPart = localEffects?.map { $0.mask.fingerprint }.joined(separator: "||") ?? "none"
        let layerMaskPart = layerMasks?.map { descriptor in
            "layer=\(descriptor.layerIndex):mask=\(descriptor.mask?.fingerprint ?? "none"):compositing=\(descriptor.compositingMask?.fingerprint ?? "none")"
        }.joined(separator: "||") ?? "none"
        return [
            "profile=\(renderProfile)",
            "intent=\(renderIntent.rawValue)",
            source.fingerprint,
            outputDerivative.fingerprint,
            "outputCache=\(outputCachePolicy.rawValue)",
            outputSemantic.fingerprint,
            "alpha=\(alphaType.rawValue)",
            "orientation=\(orientation.rawValue)",
            filters.map(\.fingerprint).joined(separator: " -> "),
            "localEffects=\(localEffectPart)",
            "layerMasks=\(layerMaskPart)"
        ].joined(separator: " || ")
    }
}

extension C7FilterProtocol {
    public var recipeDescriptor: FilterRecipeDescriptor {
        FilterRecipeDescriptor(
            stableTypeID: stableTypeID,
            modifier: modifier.recipeName,
            parameterValues: factors.map { Self.stableFloatDescription($0) },
            otherInputTextureCount: otherInputTextures.count,
            hasCount: hasCount
        )
    }

    public static func stableFloatDescription(_ value: Float) -> String {
        stableRecipeFloatDescription(value)
    }
}

extension Array where Element == C7FilterProtocol {
    public var chainRecipe: FilterChainRecipe {
        FilterChainRecipe(filters: map(\.recipeDescriptor))
    }
}

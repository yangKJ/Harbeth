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

struct FilterRecipeDescriptor: Sendable, Hashable, Codable {
    let stableTypeID: String
    let modifier: String
    let parameterValues: [String]
    let otherInputTextureCount: Int
    let pipelineFilterFingerprints: [String]
    let finalFilterFingerprint: String?

    var fingerprint: String {
        var components = [
            stableTypeID,
            modifier,
            parameterValues.joined(separator: ","),
            "inputs=\(otherInputTextureCount)"
        ]
        if pipelineFilterFingerprints.isEmpty == false {
            components.append("pipeline=\(pipelineFilterFingerprints.joined(separator: " -> "))")
        }
        if let finalFilterFingerprint {
            components.append("final=\(finalFilterFingerprint)")
        }
        return components.joined(separator: "|")
    }
}

struct FilterChainRecipe: Sendable, Hashable, Codable {
    let filters: [FilterRecipeDescriptor]

    init(filters: [FilterRecipeDescriptor]) {
        self.filters = filters
    }

    var fingerprint: String {
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
    public let path: MaskPathDescriptor?

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
        if let path {
            parts.append("path=\(path.fingerprint)")
        }
        return parts.joined(separator: ",")
    }
}

public struct MaskGradientDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let fingerprint: String
    public let parameterValues: [String]
}

public struct MaskShapeDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let fingerprint: String
    public let parameterValues: [String]
}

public struct MaskPathDescriptor: Sendable, Hashable, Codable {
    public let fillRule: String
    public let fingerprint: String
    public let pointCount: Int
    public let subpathCount: Int
    public let parameterValues: [String]
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
    public let path: MaskPathDescriptor?
}

struct LocalEffectRecipeDescriptor: Sendable, Hashable, Codable {
    let filters: [FilterRecipeDescriptor]
    let mask: MaskGraphDescriptor
    let foregroundBlendMode: String?
    let foregroundBlendOpacity: Float

    init(filters: [FilterRecipeDescriptor], mask: MaskGraphDescriptor, foregroundBlendMode: String? = nil, foregroundBlendOpacity: Float = 1.0) {
        self.filters = filters
        self.mask = mask
        self.foregroundBlendMode = foregroundBlendMode
        self.foregroundBlendOpacity = foregroundBlendOpacity
    }
}

struct LayerMaskRecipeDescriptor: Sendable, Hashable, Codable {
    let layerIndex: Int
    let mask: MaskGraphDescriptor?
    let compositingMask: MaskGraphDescriptor?
}

struct RenderRecipe: Sendable, Hashable, Codable {
    let renderProfile: String
    let renderIntent: RenderIntent
    let source: ImageSourceDescriptor
    let outputDerivative: ImageDerivativeSpec
    let outputCachePolicy: ImageCachePolicy
    let outputSemantic: ImageSemanticDescriptor
    let alphaType: AlphaType
    let orientation: FrameOrientation
    let filters: [FilterRecipeDescriptor]
    let localEffects: [LocalEffectRecipeDescriptor]?
    let layerMasks: [LayerMaskRecipeDescriptor]?

    var fingerprint: String {
        let localEffectPart = localEffects?.map { descriptor in
            let blend = descriptor.foregroundBlendMode ?? "none"
            return "\(descriptor.mask.fingerprint):blend=\(blend):opacity=\(String(format: "%.4f", descriptor.foregroundBlendOpacity))"
        }.joined(separator: "||") ?? "none"
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
    var recipeDescriptor: FilterRecipeDescriptor {
        if let pipelineFilter = self as? C7FilterPipelineProtocol {
            let pipelineDescriptors = pipelineFilter.pipelineFilters.map(\.recipeDescriptor)
            let finalDescriptor = pipelineFilter.makeFinalFilter(otherInputTextures: nil)?.recipeDescriptor
            return FilterRecipeDescriptor(
                stableTypeID: stableTypeID,
                modifier: "pipeline(\(pipelineFilter.pipelineExecutionStyle.rawValue))",
                parameterValues: pipelineDescriptors.map(\.fingerprint),
                otherInputTextureCount: pipelineFilter.pipelineOtherInputCount,
                pipelineFilterFingerprints: pipelineDescriptors.map(\.fingerprint),
                finalFilterFingerprint: finalDescriptor?.fingerprint
            )
        }
        let bindings = kernelParameterBindings
        return FilterRecipeDescriptor(
            stableTypeID: stableTypeID,
            modifier: modifier.recipeName,
            parameterValues: bindings.isEmpty ? factors.map { Self.stableFloatDescription($0) } : bindings.map(\.fingerprint),
            otherInputTextureCount: otherInputTextures.count,
            pipelineFilterFingerprints: [],
            finalFilterFingerprint: nil
        )
    }

    static func stableFloatDescription(_ value: Float) -> String {
        stableRecipeFloatDescription(value)
    }
}

extension Array where Element == C7FilterProtocol {
    var chainRecipe: FilterChainRecipe {
        FilterChainRecipe(filters: map(\.recipeDescriptor))
    }
}

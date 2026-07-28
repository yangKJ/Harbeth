//
//  FilterRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

struct FilterRecipeDescriptor: Sendable, Hashable, Codable {
    let stableTypeID: String
    let modifier: String
    let parameterValues: [String]
    let resourceIdentity: String?
    let otherInputTextureCount: Int
    let pipelineFilterFingerprints: [String]
    let finalFilterFingerprint: String?

    var fingerprint: String {
        var components = [
            stableTypeID,
            modifier,
            parameterValues.joined(separator: ","),
            "resource=\(resourceIdentity ?? "none")",
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

    /// 只描述会改变画面内容的配方部分。profile、derivative、缓存和交付语义
    /// 由 render parity 的 delivery 维度单独比较，避免把合法的预览/导出差异
    /// 误报为编辑内容漂移。
    var processingFingerprint: String {
        let localEffectPart = localEffects?.map { descriptor in
            let blend = descriptor.foregroundBlendMode ?? "none"
            return "\(descriptor.mask.fingerprint):blend=\(blend):opacity=\(String(format: "%.4f", descriptor.foregroundBlendOpacity))"
        }.joined(separator: "||") ?? "none"
        let layerMaskPart = layerMasks?.map { descriptor in
            "layer=\(descriptor.layerIndex):mask=\(descriptor.mask?.fingerprint ?? "none"):compositing=\(descriptor.compositingMask?.fingerprint ?? "none")"
        }.joined(separator: "||") ?? "none"
        return [
            "sourceKind=\(source.kind)",
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
                resourceIdentity: pipelineFilter.kernelResourceIdentity,
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
            resourceIdentity: kernelResourceIdentity,
            otherInputTextureCount: otherInputTextures.count,
            pipelineFilterFingerprints: [],
            finalFilterFingerprint: nil
        )
    }

    static func stableFloatDescription(_ value: Float) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

extension Array where Element == C7FilterProtocol {
    var chainRecipe: FilterChainRecipe {
        FilterChainRecipe(filters: map(\.recipeDescriptor))
    }
}

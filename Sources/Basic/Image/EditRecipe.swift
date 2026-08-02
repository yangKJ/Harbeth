//
//  EditRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

public enum EditRecipeMode: String, Sendable, Codable, Equatable, Hashable {
    case preview
    case final
}

struct EditRecipeContract: Sendable, Equatable {
    let mode: EditRecipeMode
    let profile: RenderProfile
    let renderIntent: RenderIntent
    let derivative: ImageDerivativeSpec
    let sourceTier: ImageSourceTier
}

public struct EditRecipe {
    public var sourceLoadingOptions: ImageLoadingOptions
    public var optics: OpticsRecipe?
    public var geometry: ImageTransformRecipe
    public var localEffects: [LocalEffectRecipe]
    public var previewProfile: RenderProfile
    public var finalProfile: RenderProfile
    public var previewDerivative: ImageDerivativeSpec
    public var finalDerivative: ImageDerivativeSpec

    public init(sourceLoadingOptions: ImageLoadingOptions = .default,
                optics: OpticsRecipe? = nil,
                geometry: ImageTransformRecipe = ImageTransformRecipe(),
                localEffects: [LocalEffectRecipe] = [],
                previewProfile: RenderProfile = .stablePreview,
                finalProfile: RenderProfile = .exportQuality,
                previewDerivative: ImageDerivativeSpec? = nil,
                finalDerivative: ImageDerivativeSpec? = nil) {
        self.sourceLoadingOptions = sourceLoadingOptions
        self.optics = optics
        self.geometry = geometry
        self.localEffects = localEffects
        self.previewProfile = previewProfile
        self.finalProfile = finalProfile
        self.previewDerivative = previewDerivative ?? previewProfile.defaultDerivativeSpec
        self.finalDerivative = finalDerivative ?? finalProfile.defaultDerivativeSpec
    }

    func contract(for mode: EditRecipeMode) -> EditRecipeContract {
        switch mode {
        case .preview:
            return EditRecipeContract(
                mode: mode,
                profile: previewProfile,
                renderIntent: previewProfile.defaultRenderIntent,
                derivative: previewDerivative,
                sourceTier: previewDerivative.sourceTier
            )
        case .final:
            return EditRecipeContract(
                mode: mode,
                profile: finalProfile,
                renderIntent: finalProfile.defaultRenderIntent,
                derivative: finalDerivative,
                sourceTier: finalDerivative.sourceTier
            )
        }
    }

    public func makeFilterChain(inputSize: C7Size, prefersQualityResize: Bool = true) -> [C7FilterProtocol] {
        makeBaseFilterChain(inputSize: inputSize, prefersQualityResize: prefersQualityResize)
    }

    public func makeNode(source: ImageSource, mode: EditRecipeMode = .preview) -> ImageNode {
        .recipe(source: source, recipe: self, mode: mode)
    }

    func planningDescriptor(for mode: EditRecipeMode) -> EditRecipePlanningDescriptor {
        let baseFilters = makeBaseFilterChain(inputSize: C7Size(width: 1, height: 1))
        let localEffectDescriptors = localEffects.map(\.recipeDescriptor)
        let localEffectCount = localEffects.reduce(0) { partial, effect in
            partial + effect.filters.count + 1 + (effect.foregroundBlendType == nil ? 0 : 1)
        }
        return EditRecipePlanningDescriptor(
            sourceLoadingOptions: sourceLoadingOptions,
            contract: contract(for: mode),
            baseFilterChain: FilterChainRecipe(filters: baseFilters.map(\.recipeDescriptor)),
            localEffects: localEffectDescriptors,
            filterCount: baseFilters.count + localEffectCount
        )
    }

    func makeRenderPlan(source: ImageSource,
                        mode: EditRecipeMode = .preview,
                        extraFilters: [C7FilterProtocol] = [],
                        derivative: ImageDerivativeSpec? = nil,
                        samplerDescriptor: ImageSamplerDescriptor = .default) throws -> RenderPlan {
        let compiled = try compileExecution(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative
        )
        return RenderExecutionCompiler.compile(
            filters: compiled.diagnosticFilters,
            inputSize: compiled.inputSize,
            profile: compiled.profile,
            derivative: compiled.derivative,
            compilationSource: .editRecipe,
            samplerDescriptor: samplerDescriptor,
            sourceDescriptor: compiled.source.descriptor
        ).plan
    }

    func makeRenderRecipe(source: ImageSource,
                          mode: EditRecipeMode = .preview,
                          extraFilters: [C7FilterProtocol] = [],
                          derivative: ImageDerivativeSpec? = nil,
                          samplerDescriptor: ImageSamplerDescriptor = .default,
                          sourceDescriptorOverride: ImageSourceDescriptor? = nil,
                          alphaTypeOverride: AlphaType? = nil,
                          orientationOverride: FrameOrientation? = nil) throws -> RenderRecipe {
        let compiled = try compileExecution(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative
        )
        let plan = RenderExecutionCompiler.compile(
            filters: compiled.diagnosticFilters,
            inputSize: compiled.inputSize,
            profile: compiled.profile,
            derivative: compiled.derivative,
            compilationSource: .editRecipe,
            samplerDescriptor: samplerDescriptor,
            sourceDescriptor: compiled.source.descriptor
        ).plan
        let filters = plan.diagnostics.nodes
            .filter { $0.name != "DerivativeResize" }
            .map { diagnostic in
                FilterRecipeDescriptor(
                    stableTypeID: diagnostic.name,
                    modifier: diagnostic.kind.rawValue,
                    parameterValues: diagnostic.parameterSummary.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" },
                    resourceIdentity: nil,
                    otherInputTextureCount: 0,
                    pipelineFilterFingerprints: [],
                    finalFilterFingerprint: nil
                )
            }
        return RenderRecipe(
            renderProfile: String(describing: compiled.profile),
            renderIntent: compiled.derivative.renderIntent,
            source: sourceDescriptorOverride ?? compiled.source.descriptor,
            outputDerivative: compiled.derivative,
            outputCachePolicy: compiled.outputCachePolicy,
            outputSemantic: compiled.derivative.semantic,
            alphaType: alphaTypeOverride ?? compiled.source.alphaType,
            orientation: orientationOverride ?? compiled.source.orientation,
            filters: filters,
            localEffects: localEffects.isEmpty ? nil : localEffects.map(\.recipeDescriptor),
            layerMasks: nil
        )
    }

    func resolvedSource(_ source: ImageSource) -> ImageSource {
        switch source {
        case .asset(let asset):
            return .asset(
                ImageAsset(
                    storage: asset.storage,
                    loadingOptions: sourceLoadingOptions,
                    sourceTier: asset.sourceTier
                )
            )
        default:
            return source
        }
    }

    func makeBaseFilterChain(inputSize: C7Size,
                             prefersQualityResize: Bool = true,
                             appending extraFilters: [C7FilterProtocol] = []) -> [C7FilterProtocol] {
        var filters: [C7FilterProtocol] = []
        if let optics, optics.isIdentity == false {
            filters.append(contentsOf: optics.makeFilters())
        }
        filters.append(contentsOf: geometry.makeFilters(inputSize: inputSize, prefersQualityResize: prefersQualityResize))
        filters.append(contentsOf: extraFilters)
        return filters
    }

    func makeExecutionPreviewChain(inputSize: C7Size,
                                   mode: EditRecipeMode,
                                   derivative: ImageDerivativeSpec,
                                   resolvedLocalEffects: [ResolvedLocalEffect],
                                   appending extraFilters: [C7FilterProtocol] = [],
                                   includeDerivativeResize: Bool = true) -> [C7FilterProtocol] {
        var compiled = makeBaseFilterChain(inputSize: inputSize, appending: extraFilters)
        resolvedLocalEffects.forEach { effect in
            compiled.append(contentsOf: effect.filters)
            let placeholderMask = effect.mask
            compiled.append(MaskRegionBlend(effectTexture: placeholderMask.texture, mask: placeholderMask))
        }
        guard includeDerivativeResize else {
            return compiled
        }
        let baseOutputSize = compiled.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
        let derivativeOutputSize = derivative.resolvedOutputSize(for: baseOutputSize)
        guard derivativeOutputSize != baseOutputSize else {
            return compiled
        }
        compiled.append(
            C7Resize(
                width: Float(derivativeOutputSize.width),
                height: Float(derivativeOutputSize.height)
            )
        )
        return compiled
    }

    func compileExecution(source: ImageSource,
                          mode: EditRecipeMode,
                          extraFilters: [C7FilterProtocol] = [],
                          derivative: ImageDerivativeSpec? = nil) throws -> CompiledEditRecipeExecution {
        let resolvedSource = resolvedSource(source)
        let input = try resolvedSource.makeTexture()
        let inputSize = C7Size(texture: input)
        let contract = contract(for: mode)
        let effectiveDerivative = derivative ?? contract.derivative
        let baseFilters = makeBaseFilterChain(inputSize: inputSize, appending: extraFilters)
        let resolvedLocalEffects = try localEffects.map { effect in
            try ResolvedLocalEffect(
                filters: effect.filters,
                mask: effect.resolvedMaskDescriptor(),
                foregroundBlendType: effect.foregroundBlendType,
                foregroundBlendOpacity: effect.foregroundBlendOpacity
            )
        }
        let diagnosticFilters = makeExecutionPreviewChain(
            inputSize: inputSize,
            mode: mode,
            derivative: effectiveDerivative,
            resolvedLocalEffects: resolvedLocalEffects,
            appending: extraFilters
        )
        let outputCachePolicy: ImageCachePolicy =
            (geometry.isIdentity && (optics?.isIdentity ?? true) && localEffects.isEmpty && extraFilters.isEmpty)
            ? resolvedSource.cachePolicy
            : .transient
        return CompiledEditRecipeExecution(
            source: resolvedSource,
            contract: contract,
            derivative: effectiveDerivative,
            inputTexture: input,
            inputSize: inputSize,
            baseFilters: baseFilters,
            localEffects: resolvedLocalEffects,
            diagnosticFilters: diagnosticFilters,
            outputCachePolicy: outputCachePolicy
        )
    }
}

struct ResolvedLocalEffect {
    let filters: [C7FilterProtocol]
    let mask: MaskDescriptor
    let foregroundBlendType: C7Blend.BlendType?
    let foregroundBlendOpacity: Float
}

struct EditRecipePlanningDescriptor {
    let sourceLoadingOptions: ImageLoadingOptions
    let contract: EditRecipeContract
    let baseFilterChain: FilterChainRecipe
    let localEffects: [LocalEffectRecipeDescriptor]
    let filterCount: Int

    var fingerprint: String {
        let baseFingerprint = baseFilterChain.filters.isEmpty ? "none" : baseFilterChain.fingerprint
        let localEffectsFingerprint = localEffects.isEmpty ? "none" : localEffects.map(\.fingerprint).joined(separator: "||")
        return [
            "loading=\(sourceLoadingOptions.fingerprint)",
            "profile=\(contract.profile)",
            contract.derivative.fingerprint,
            "base=\(baseFingerprint)",
            "localEffects=\(localEffectsFingerprint)"
        ].joined(separator: "|")
    }
}

struct CompiledEditRecipeExecution {
    let source: ImageSource
    let contract: EditRecipeContract
    let derivative: ImageDerivativeSpec
    let inputTexture: MTLTexture
    let inputSize: C7Size
    let baseFilters: [C7FilterProtocol]
    let localEffects: [ResolvedLocalEffect]
    let diagnosticFilters: [C7FilterProtocol]
    let outputCachePolicy: ImageCachePolicy

    var profile: RenderProfile {
        contract.profile
    }

    var resolvedOutputSize: C7Size {
        diagnosticFilters.reduce(inputSize) { size, filter in
            filter.resize(input: size)
        }
    }
}

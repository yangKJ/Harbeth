//
//  EditRecipe.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation

public enum EditRecipeMode: String, Sendable, Codable, Equatable, Hashable {
    case preview
    case final
}

public struct EditRecipeContract: Sendable, Equatable {
    public let mode: EditRecipeMode
    public let profile: RenderProfile
    public let renderIntent: RenderIntent
    public let derivative: ImageDerivativeSpec
    public let sourceTier: ImageSourceTier

    public init(mode: EditRecipeMode,
                profile: RenderProfile,
                renderIntent: RenderIntent,
                derivative: ImageDerivativeSpec,
                sourceTier: ImageSourceTier) {
        self.mode = mode
        self.profile = profile
        self.renderIntent = renderIntent
        self.derivative = derivative
        self.sourceTier = sourceTier
    }
}

public struct EditRecipe {
    public var sourceLoadingOptions: ImageLoadingOptions
    public var geometry: ImageTransformRecipe
    public var filters: [C7FilterProtocol]
    public var localEffects: [LocalEffectRecipe]
    public var previewProfile: RenderProfile
    public var finalProfile: RenderProfile
    public var previewDerivative: ImageDerivativeSpec
    public var finalDerivative: ImageDerivativeSpec

    public init(sourceLoadingOptions: ImageLoadingOptions = .default,
                geometry: ImageTransformRecipe = ImageTransformRecipe(),
                filters: [C7FilterProtocol] = [],
                localEffects: [LocalEffectRecipe] = [],
                previewProfile: RenderProfile = .stablePreview,
                finalProfile: RenderProfile = .exportQuality,
                previewDerivative: ImageDerivativeSpec? = nil,
                finalDerivative: ImageDerivativeSpec? = nil) {
        self.sourceLoadingOptions = sourceLoadingOptions
        self.geometry = geometry
        self.filters = filters
        self.localEffects = localEffects
        self.previewProfile = previewProfile
        self.finalProfile = finalProfile
        self.previewDerivative = previewDerivative ?? previewProfile.defaultDerivativeSpec
        self.finalDerivative = finalDerivative ?? finalProfile.defaultDerivativeSpec
    }

    public func contract(for mode: EditRecipeMode) -> EditRecipeContract {
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

    func resolvedSource(_ source: HarbethSource) -> HarbethSource {
        switch source {
        case .asset(let asset):
            return .asset(
                HarbethImageAsset(
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
        geometry.makeFilters(inputSize: inputSize, prefersQualityResize: prefersQualityResize) + filters + extraFilters
    }

    func makeExecutionPreviewChain(inputSize: C7Size,
                                   mode: EditRecipeMode,
                                   derivative: ImageDerivativeSpec,
                                   appending extraFilters: [C7FilterProtocol] = [],
                                   includeDerivativeResize: Bool = true) -> [C7FilterProtocol] {
        var compiled = makeBaseFilterChain(inputSize: inputSize, appending: extraFilters)
        localEffects.forEach { effect in
            compiled.append(contentsOf: effect.filters)
            let placeholderMask = effect.mask
            compiled.append(C7MaskRegionBlend(effectTexture: placeholderMask.texture, mask: placeholderMask))
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
}

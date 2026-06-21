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

    public func makeNode(source: ImageSource, mode: EditRecipeMode = .preview) -> ImageNode {
        .recipe(source: source, recipe: self, mode: mode)
    }

    public func makeRenderPlan(source: ImageSource,
                               mode: EditRecipeMode = .preview,
                               extraFilters: [C7FilterProtocol] = [],
                               derivative: ImageDerivativeSpec? = nil) throws -> RenderPlan {
        let compiled = try compileExecution(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative
        )
        return GraphCompiler.compile(
            filters: compiled.diagnosticFilters,
            inputSize: compiled.inputSize,
            profile: compiled.profile,
            derivative: compiled.derivative,
            compilationSource: .editRecipe,
            sourceDescriptor: compiled.source.descriptor
        )
    }

    public func makeRenderRecipe(source: ImageSource,
                                 mode: EditRecipeMode = .preview,
                                 extraFilters: [C7FilterProtocol] = [],
                                 derivative: ImageDerivativeSpec? = nil) throws -> RenderRecipe {
        let compiled = try compileExecution(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative
        )
        let plan = GraphCompiler.compile(
            filters: compiled.diagnosticFilters,
            inputSize: compiled.inputSize,
            profile: compiled.profile,
            derivative: compiled.derivative,
            compilationSource: .editRecipe,
            sourceDescriptor: compiled.source.descriptor
        )
        return RenderRecipe(
            renderProfile: String(describing: compiled.profile),
            renderIntent: compiled.derivative.renderIntent,
            source: compiled.source.descriptor,
            outputDerivative: compiled.derivative,
            outputCachePolicy: compiled.outputCachePolicy,
            outputSemantic: compiled.derivative.semantic,
            alphaType: compiled.source.alphaType,
            orientation: compiled.source.orientation,
            filters: plan.diagnostics.nodes
                .filter { $0.name != "DerivativeResize" }
                .map { diagnostic in
                    FilterRecipeDescriptor(
                        stableTypeID: diagnostic.name,
                        modifier: diagnostic.kind.rawValue,
                        parameterValues: diagnostic.parameterSummary
                            .sorted { $0.key < $1.key }
                            .map { "\($0.key)=\($0.value)" },
                        otherInputTextureCount: 0,
                        hasCount: false
                    )
                }
        )
    }

    public func makeRenderRequest(source: ImageSource,
                                  mode: EditRecipeMode = .preview,
                                  extraFilters: [C7FilterProtocol] = [],
                                  derivative: ImageDerivativeSpec? = nil,
                                  identifier: String = UUID().uuidString) throws -> RenderRequest {
        let compiled = try compileExecution(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative
        )
        let plan = try makeRenderPlan(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative
        )
        let recipeDescriptor = try makeRenderRecipe(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative
        )
        return RenderRequest(
            compilationSource: .editRecipe,
            profile: compiled.profile,
            derivative: compiled.derivative,
            source: compiled.source.descriptor,
            outputCachePolicy: compiled.outputCachePolicy,
            diagnostics: plan.diagnostics,
            renderRecipe: recipeDescriptor,
            renderTexture: {
                let renderTexture: (MTLTexture, [C7FilterProtocol], RenderProfile) throws -> MTLTexture = { input, filters, profile in
                    guard filters.isEmpty == false else { return input }
                    return try HarbethIO(element: input, filters: filters)
                        .configured(for: profile)
                        .output()
                }
                var currentTexture = try renderTexture(compiled.inputTexture, compiled.baseFilters, compiled.profile)
                for localEffect in compiled.localEffects {
                    let effectTexture = try renderTexture(currentTexture, localEffect.filters, compiled.profile)
                    currentTexture = try renderTexture(
                        currentTexture,
                        [C7MaskRegionBlend(effectTexture: effectTexture, mask: localEffect.mask)],
                        compiled.profile
                    )
                }
                let targetSize = compiled.derivative.resolvedOutputSize(for: C7Size(width: currentTexture.width, height: currentTexture.height))
                guard targetSize.width != currentTexture.width || targetSize.height != currentTexture.height else {
                    return currentTexture
                }
                return try HarbethIO(
                    element: currentTexture,
                    filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height))
                )
                .configured(for: compiled.profile)
                .output()
            },
            renderFrame: { metadata in
                try FrameRenderer(
                    source: compiled.source,
                    recipe: self,
                    mode: mode,
                    filters: extraFilters,
                    identifier: identifier,
                    metadata: metadata,
                    derivative: compiled.derivative
                ).renderFrame()
            }
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

    func compileExecution(source: ImageSource,
                          mode: EditRecipeMode,
                          extraFilters: [C7FilterProtocol] = [],
                          derivative: ImageDerivativeSpec? = nil) throws -> CompiledEditRecipeExecution {
        let resolvedSource = resolvedSource(source)
        let input = try resolvedSource.makeTexture()
        let inputSize = C7Size(width: input.width, height: input.height)
        let contract = contract(for: mode)
        let effectiveDerivative = derivative ?? contract.derivative
        let baseFilters = makeBaseFilterChain(inputSize: inputSize, appending: extraFilters)
        let diagnosticFilters = makeExecutionPreviewChain(
            inputSize: inputSize,
            mode: mode,
            derivative: effectiveDerivative,
            appending: extraFilters
        )
        let outputCachePolicy: ImageCachePolicy =
            (geometry.isIdentity && filters.isEmpty && localEffects.isEmpty && extraFilters.isEmpty)
            ? resolvedSource.cachePolicy
            : .transient
        return CompiledEditRecipeExecution(
            source: resolvedSource,
            contract: contract,
            derivative: effectiveDerivative,
            inputTexture: input,
            inputSize: inputSize,
            baseFilters: baseFilters,
            localEffects: localEffects,
            diagnosticFilters: diagnosticFilters,
            outputCachePolicy: outputCachePolicy
        )
    }
}

struct CompiledEditRecipeExecution {
    let source: ImageSource
    let contract: EditRecipeContract
    let derivative: ImageDerivativeSpec
    let inputTexture: MTLTexture
    let inputSize: C7Size
    let baseFilters: [C7FilterProtocol]
    let localEffects: [LocalEffectRecipe]
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

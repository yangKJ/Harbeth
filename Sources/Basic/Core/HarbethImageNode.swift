//
//  HarbethImageNode.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import Metal

public protocol HarbethImagePromise {
    var compilationSource: RenderCompilationSource { get }
    func makeTexture(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> MTLTexture
    func makeDiagnostics(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> RenderPlanDiagnostics
}

public indirect enum HarbethImageNode {
    case source(HarbethSource)
    case filters(input: HarbethImageNode, filters: [C7FilterProtocol])
    case kernel(input: HarbethImageNode, descriptor: HarbethKernelDescriptor, filter: C7FilterProtocol)
    case recipe(source: HarbethSource, recipe: EditRecipe, mode: EditRecipeMode)
    case transition(TransitionRecipe)
    case layerComposite(LayerCompositeRecipe)

    public static func source(_ source: HarbethSource, filters: [C7FilterProtocol]) -> HarbethImageNode {
        .filters(input: .source(source), filters: filters)
    }
}

extension HarbethImageNode: HarbethImagePromise {
    public var compilationSource: RenderCompilationSource {
        switch self {
        case .source, .filters, .kernel:
            return .nodeGraph
        case .recipe:
            return .editRecipe
        case .transition:
            return .transition
        case .layerComposite:
            return .layerComposite
        }
    }

    public func makeTexture(profile: RenderProfile = .stablePreview,
                            derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        switch self {
        case .source(let source):
            let texture = try source.makeTexture()
            return try resizeTextureIfNeeded(texture, derivative: derivative ?? profile.defaultDerivativeSpec, profile: profile)
        case .filters(let input, let filters):
            let inputTexture = try input.makeTexture(profile: profile, derivative: nil)
            guard filters.isEmpty == false else {
                return try resizeTextureIfNeeded(inputTexture, derivative: derivative ?? profile.defaultDerivativeSpec, profile: profile)
            }
            let rendered = try HarbethIO(element: inputTexture, filters: filters)
                .configured(for: profile)
                .output()
            return try resizeTextureIfNeeded(rendered, derivative: derivative ?? profile.defaultDerivativeSpec, profile: profile)
        case .kernel(let input, _, let filter):
            let inputTexture = try input.makeTexture(profile: profile, derivative: nil)
            let rendered = try HarbethIO(element: inputTexture, filter: filter)
                .configured(for: profile)
                .output()
            return try resizeTextureIfNeeded(rendered, derivative: derivative ?? profile.defaultDerivativeSpec, profile: profile)
        case .recipe(let source, let recipe, let mode):
            return try FrameRenderer(
                source: source,
                recipe: recipe,
                mode: mode,
                derivative: derivative
            ).renderTexture()
        case .transition(let recipe):
            return try FrameRenderer(
                transitionRecipe: recipe
            ).renderTexture()
        case .layerComposite(let recipe):
            return try recipe.makeTexture(derivative: derivative)
        }
    }

    public func makeDiagnostics(profile: RenderProfile = .stablePreview,
                                derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        switch self {
        case .source(let source):
            let texture = try source.makeTexture()
            return GraphCompiler.compile(
                filters: [],
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph
            ).diagnostics
        case .filters(let input, let filters):
            let texture = try input.makeTexture(profile: profile, derivative: nil)
            return GraphCompiler.compile(
                filters: filters,
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph
            ).diagnostics
        case .kernel(let input, let descriptor, let filter):
            let texture = try input.makeTexture(profile: profile, derivative: nil)
            let outputContract = RenderOutputContract(alpha: descriptor.alphaBehavior.renderAlphaContract)
            return GraphCompiler.compile(
                filters: [filter],
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph,
                outputContract: outputContract
            ).diagnostics
        case .recipe(let source, let recipe, let mode):
            let texture = try recipe.resolvedSource(source).makeTexture()
            let contract = recipe.contract(for: mode)
            let effectiveDerivative = derivative ?? contract.derivative
            let filters = recipe.makeExecutionPreviewChain(
                inputSize: C7Size(width: texture.width, height: texture.height),
                mode: mode,
                derivative: effectiveDerivative,
                includeDerivativeResize: false
            )
            return GraphCompiler.compile(
                filters: filters,
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: contract.profile,
                derivative: effectiveDerivative,
                compilationSource: .editRecipe
            ).diagnostics
        case .transition(let recipe):
            let texture = try recipe.from.makeTexture()
            return GraphCompiler.compile(
                filters: [try recipe.makeFilter()],
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: recipe.profile,
                derivative: derivative ?? recipe.derivative,
                compilationSource: .transition
            ).diagnostics
        case .layerComposite(let recipe):
            return try recipe.makeDiagnostics(derivative: derivative)
        }
    }

    public func makeFrame(profile: RenderProfile = .stablePreview,
                          derivative: ImageDerivativeSpec? = nil,
                          metadata: [String: String] = [:]) throws -> RenderedFrame {
        let texture = try makeTexture(profile: profile, derivative: derivative)
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        return try FrameRenderer(
            source: .texture(texture),
            filters: [],
            profile: profile,
            renderIntent: effectiveDerivative.renderIntent,
            metadata: metadata,
            outputSemantic: effectiveDerivative.semantic,
            outputDerivative: effectiveDerivative,
            outputCachePolicy: .transient
        ).renderFrame()
    }

    private func resizeTextureIfNeeded(_ texture: MTLTexture,
                                       derivative: ImageDerivativeSpec,
                                       profile: RenderProfile) throws -> MTLTexture {
        let targetSize = derivative.resolvedOutputSize(for: C7Size(width: texture.width, height: texture.height))
        guard targetSize.width != texture.width || targetSize.height != texture.height else {
            return texture
        }
        return try HarbethIO(
            element: texture,
            filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height))
        )
        .configured(for: profile)
        .output()
    }
}

private extension HarbethKernelAlphaBehavior {
    var renderAlphaContract: ImageAlphaContract {
        switch self {
        case .preserveInput:
            return .preserveInput
        case .outputsOpaque:
            return .opaque
        case .outputsPremultiplied:
            return .premultiplied
        case .outputsNonPremultiplied:
            return .nonPremultiplied
        case .modifiesAlpha:
            return .preserveInput
        }
    }
}

extension LayerCompositeRecipe {
    func makeTexture(derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        var current = try background.makeTexture()
        guard layers.isEmpty == false else {
            return try resizeTextureIfNeeded(current, derivative: derivative ?? self.derivative)
        }

        for layer in layers {
            var layerTexture = try layer.content.makeTexture()
            let layerFilters = layer.transform.makeFilters(
                inputSize: C7Size(width: layerTexture.width, height: layerTexture.height)
            ) + layer.filters
            if layerFilters.isEmpty == false {
                layerTexture = try HarbethIO(element: layerTexture, filters: layerFilters)
                    .configured(for: profile)
                    .output()
            }
            current = try HarbethIO(
                element: current,
                filter: C7LayerComposite(
                    layerTexture: layerTexture,
                    mask: layer.mask,
                    compositingMask: layer.compositingMask,
                    normalizedFrame: layer.normalizedFrame,
                    opacity: layer.opacity,
                    blendMode: layer.blendMode,
                    cornerRadius: layer.cornerRadius
                )
            )
            .configured(for: profile)
            .output()
        }
        return try resizeTextureIfNeeded(current, derivative: derivative ?? self.derivative)
    }

    func makeDiagnostics(derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        let backgroundTexture = try background.makeTexture()
        let backgroundSize = C7Size(width: backgroundTexture.width, height: backgroundTexture.height)
        let placeholderTexture = backgroundTexture
        let filters = layers.map { layer in
            C7LayerComposite(
                layerTexture: placeholderTexture,
                mask: layer.mask,
                compositingMask: layer.compositingMask,
                normalizedFrame: layer.normalizedFrame,
                opacity: layer.opacity,
                blendMode: layer.blendMode,
                cornerRadius: layer.cornerRadius
            )
        }
        return GraphCompiler.compile(
            filters: filters,
            inputSize: backgroundSize,
            profile: profile,
            derivative: derivative ?? self.derivative,
            compilationSource: .layerComposite,
            outputContract: outputContract
        ).diagnostics
    }

    private func resizeTextureIfNeeded(_ texture: MTLTexture,
                                       derivative: ImageDerivativeSpec) throws -> MTLTexture {
        let targetSize = derivative.resolvedOutputSize(for: C7Size(width: texture.width, height: texture.height))
        guard targetSize.width != texture.width || targetSize.height != texture.height else {
            return texture
        }
        return try HarbethIO(
            element: texture,
            filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height))
        )
        .configured(for: profile)
        .output()
    }
}

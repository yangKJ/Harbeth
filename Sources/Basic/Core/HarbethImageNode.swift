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
    case cachePolicy(input: HarbethImageNode, policy: ImageCachePolicy)
    case samplerDescriptor(input: HarbethImageNode, descriptor: ImageSamplerDescriptor)

    public static func source(_ source: HarbethSource, filters: [C7FilterProtocol]) -> HarbethImageNode {
        .filters(input: .source(source), filters: filters)
    }

    public func withCachePolicy(_ policy: ImageCachePolicy) -> HarbethImageNode {
        .cachePolicy(input: self, policy: policy)
    }

    public func withSamplerDescriptor(_ descriptor: ImageSamplerDescriptor) -> HarbethImageNode {
        .samplerDescriptor(input: self, descriptor: descriptor)
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
        case .cachePolicy(let input, _):
            return input.compilationSource
        case .samplerDescriptor(let input, _):
            return input.compilationSource
        }
    }

    public func makeTexture(profile: RenderProfile = .stablePreview,
                            derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        let effectiveCachePolicy = resolvedCachePolicy
        let fingerprint = resolutionFingerprint(profile: profile, derivative: derivative)
        if effectiveCachePolicy == .persistent,
           let cached = Shared.shared.defaultContext.cachedResolvedTexture(for: fingerprint) {
            Shared.shared.performanceMonitor?.recordImageResolutionCacheLookup("imageResolution", hit: true)
            return cached
        }
        if effectiveCachePolicy == .persistent {
            Shared.shared.performanceMonitor?.recordImageResolutionCacheLookup("imageResolution", hit: false)
        }
        let texture = try makeTextureUncached(profile: profile, derivative: derivative)
        if effectiveCachePolicy == .persistent {
            Shared.shared.defaultContext.storeResolvedTexture(texture, for: fingerprint)
        }
        return texture
    }

    private func makeTextureUncached(profile: RenderProfile,
                                     derivative: ImageDerivativeSpec?) throws -> MTLTexture {
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
        case .kernel(let input, let descriptor, let filter):
            let inputTexture = try input.makeTexture(profile: profile, derivative: nil)
            let rendered = try HarbethIO(element: inputTexture, filter: filter)
                .configured(for: profile)
                .output()
            let contracted = try HarbethImageNode.applyOutputContractIfNeeded(
                descriptor.outputContract,
                to: rendered,
                profile: profile
            )
            return try resizeTextureIfNeeded(contracted, derivative: derivative ?? profile.defaultDerivativeSpec, profile: profile)
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
        case .cachePolicy(let input, _):
            return try input.makeTexture(profile: profile, derivative: derivative)
        case .samplerDescriptor(let input, _):
            return try input.makeTexture(profile: profile, derivative: derivative)
        }
    }

    public func resolutionFingerprint(profile: RenderProfile = .stablePreview,
                                      derivative: ImageDerivativeSpec? = nil) -> String {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        return [
            nodeFingerprint,
            "profile=\(profile)",
            effectiveDerivative.fingerprint,
            "cache=\(resolvedCachePolicy.rawValue)",
            "sampler=\(resolvedSamplerDescriptor.fingerprint)"
        ].joined(separator: " || ")
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
                compilationSource: .nodeGraph,
                imageCachePolicy: source.cachePolicy
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
            return GraphCompiler.compile(
                filters: [filter],
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph,
                outputContract: descriptor.outputContract
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
        case .cachePolicy(let input, let policy):
            return try input.makeDiagnostics(profile: profile, derivative: derivative)
                .withImageCachePolicy(policy)
        case .samplerDescriptor(let input, let descriptor):
            _ = Shared.shared.defaultContext.makeSamplerState(descriptor)
            return try input.makeDiagnostics(profile: profile, derivative: derivative)
                .withSamplerDescriptor(descriptor)
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

    private var resolvedCachePolicy: ImageCachePolicy {
        switch self {
        case .source(let source):
            return source.cachePolicy
        case .filters, .kernel, .recipe, .transition, .layerComposite:
            return .transient
        case .cachePolicy(_, let policy):
            return policy
        case .samplerDescriptor(let input, _):
            return input.resolvedCachePolicy
        }
    }

    private var resolvedSamplerDescriptor: ImageSamplerDescriptor {
        switch self {
        case .samplerDescriptor(_, let descriptor):
            return descriptor
        case .cachePolicy(let input, _):
            return input.resolvedSamplerDescriptor
        case .source, .filters, .kernel, .recipe, .transition, .layerComposite:
            return .default
        }
    }

    private var nodeFingerprint: String {
        switch self {
        case .source(let source):
            return "source|\(source.resolutionFingerprint)"
        case .filters(let input, let filters):
            return [
                "filters",
                input.nodeFingerprint,
                filters.chainRecipe.fingerprint
            ].joined(separator: "|")
        case .kernel(let input, let descriptor, let filter):
            return [
                "kernel",
                input.nodeFingerprint,
                descriptor.fingerprint,
                filter.recipeDescriptor.fingerprint
            ].joined(separator: "|")
        case .recipe(let source, let recipe, let mode):
            let contract = recipe.contract(for: mode)
            return [
                "recipe",
                source.resolutionFingerprint,
                "mode=\(mode.rawValue)",
                "profile=\(contract.profile)",
                contract.derivative.fingerprint,
                recipe.makeFilterChain(inputSize: C7Size(width: 1, height: 1)).chainRecipe.fingerprint
            ].joined(separator: "|")
        case .transition(let recipe):
            return [
                "transition",
                recipe.from.resolutionFingerprint,
                recipe.to.resolutionFingerprint,
                recipe.kernel.fingerprint,
                "progress=\(String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), recipe.progress))",
                recipe.derivative.fingerprint
            ].joined(separator: "|")
        case .layerComposite(let recipe):
            return [
                "layerComposite",
                recipe.background.resolutionFingerprint,
                recipe.layers.map { $0.content.resolutionFingerprint + "|" + $0.fingerprint }.joined(separator: "||"),
                recipe.fingerprint
            ].joined(separator: "|")
        case .cachePolicy(let input, let policy):
            return "\(input.nodeFingerprint)|cacheOverride=\(policy.rawValue)"
        case .samplerDescriptor(let input, let descriptor):
            return "\(input.nodeFingerprint)|samplerOverride=\(descriptor.fingerprint)"
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
        let contracted = try HarbethImageNode.applyOutputContractIfNeeded(
            outputContract,
            to: current,
            profile: profile
        )
        return try resizeTextureIfNeeded(contracted, derivative: derivative ?? self.derivative)
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

extension HarbethImageNode {
    static func applyOutputContractIfNeeded(_ contract: RenderOutputContract,
                                            to texture: MTLTexture,
                                            profile: RenderProfile) throws -> MTLTexture {
        let filters: [C7FilterProtocol]
        switch contract.alpha {
        case .premultiplied, .forcePremultiply:
            filters = [C7PremultiplyAlpha()]
        case .nonPremultiplied, .forceUnpremultiply:
            filters = [C7UnpremultiplyAlpha()]
        case .opaque, .preserveInput:
            filters = []
        }
        guard filters.isEmpty == false else { return texture }
        return try HarbethIO(element: texture, filters: filters)
            .configured(for: profile)
            .output()
    }
}

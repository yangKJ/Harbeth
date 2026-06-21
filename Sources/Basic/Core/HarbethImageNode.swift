//
//  HarbethImageNode.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import Metal
import CoreGraphics
import CoreVideo
import CoreMedia

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

    public static func texture(_ texture: MTLTexture) -> HarbethImageNode {
        .source(.texture(texture))
    }

    public static func image(_ image: C7Image) -> HarbethImageNode {
        .source(.image(image))
    }

    public static func cgImage(_ image: CGImage) -> HarbethImageNode {
        .source(.cgImage(image))
    }

    public static func pixelBuffer(_ pixelBuffer: CVPixelBuffer) -> HarbethImageNode {
        .source(.pixelBuffer(pixelBuffer))
    }

    public static func sampleBuffer(_ sampleBuffer: CMSampleBuffer) -> HarbethImageNode {
        .source(.sampleBuffer(sampleBuffer))
    }

    public static func data(_ data: Data) -> HarbethImageNode {
        .source(.data(data))
    }

    public static func asset(_ asset: HarbethImageAsset) -> HarbethImageNode {
        .source(.asset(asset))
    }

    public func withCachePolicy(_ policy: ImageCachePolicy) -> HarbethImageNode {
        .cachePolicy(input: self, policy: policy)
    }

    public func withSamplerDescriptor(_ descriptor: ImageSamplerDescriptor) -> HarbethImageNode {
        .samplerDescriptor(input: self, descriptor: descriptor)
    }

    public func applying(_ filter: C7FilterProtocol) -> HarbethImageNode {
        .filters(input: self, filters: [filter])
    }

    public func applying(filters: [C7FilterProtocol]) -> HarbethImageNode {
        .filters(input: self, filters: filters)
    }

    public func applying(_ invocation: HarbethKernelInvocation) -> HarbethImageNode {
        .kernel(input: self, descriptor: invocation.descriptor, filter: invocation.executableFilter)
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
                sourceColorSpace: descriptor.inputColorSpace,
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
        try makeRenderPlan(profile: profile, derivative: derivative).diagnostics
    }

    public func makeRenderPlan(profile: RenderProfile = .stablePreview,
                               derivative: ImageDerivativeSpec? = nil) throws -> RenderPlan {
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
            )
        case .filters(let input, let filters):
            let texture = try input.makeTexture(profile: profile, derivative: nil)
            return GraphCompiler.compile(
                filters: filters,
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph
            )
        case .kernel(let input, let descriptor, let filter):
            let texture = try input.makeTexture(profile: profile, derivative: nil)
            return GraphCompiler.compile(
                filters: [filter],
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph,
                outputContract: descriptor.outputContract
            )
        case .recipe(let source, let recipe, let mode):
            return try recipe.makeRenderPlan(source: source, mode: mode, derivative: derivative)
        case .transition(let recipe):
            let texture = try recipe.from.makeTexture()
            return GraphCompiler.compile(
                filters: [try recipe.makeFilter()],
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: recipe.profile,
                derivative: derivative ?? recipe.derivative,
                compilationSource: .transition
            )
        case .layerComposite(let recipe):
            return try recipe.makeRenderPlan(derivative: derivative)
        case .cachePolicy(let input, let policy):
            let plan = try input.makeRenderPlan(profile: profile, derivative: derivative)
            return RenderPlan(
                graph: plan.graph,
                profile: plan.profile,
                derivative: plan.diagnostics.derivative,
                inputSize: plan.diagnostics.inputSize,
                outputSize: plan.diagnostics.outputSize,
                nodeDiagnostics: plan.diagnostics.nodes,
                compilationSource: plan.diagnostics.compilationSource,
                outputContract: plan.diagnostics.outputContract,
                imageCachePolicy: policy,
                samplerDescriptor: plan.diagnostics.samplerDescriptor
            )
        case .samplerDescriptor(let input, let descriptor):
            _ = Shared.shared.defaultContext.makeSamplerState(descriptor)
            let plan = try input.makeRenderPlan(profile: profile, derivative: derivative)
            return RenderPlan(
                graph: plan.graph,
                profile: plan.profile,
                derivative: plan.diagnostics.derivative,
                inputSize: plan.diagnostics.inputSize,
                outputSize: plan.diagnostics.outputSize,
                nodeDiagnostics: plan.diagnostics.nodes,
                compilationSource: plan.diagnostics.compilationSource,
                outputContract: plan.diagnostics.outputContract,
                imageCachePolicy: plan.diagnostics.imageCachePolicy,
                samplerDescriptor: descriptor
            )
        }
    }

    public func makeRenderRecipe(profile: RenderProfile = .stablePreview,
                                 derivative: ImageDerivativeSpec? = nil) throws -> RenderRecipe {
        let plan = try makeRenderPlan(profile: profile, derivative: derivative)
        let primarySource = try resolvedPrimarySource()
        return RenderRecipe(
            renderProfile: String(describing: plan.profile),
            renderIntent: plan.diagnostics.derivative.renderIntent,
            source: primarySource.descriptor,
            outputDerivative: plan.diagnostics.derivative,
            outputCachePolicy: resolvedCachePolicy,
            outputSemantic: plan.diagnostics.derivative.semantic,
            alphaType: primarySource.alphaType,
            orientation: primarySource.orientation,
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

    public func makeRenderRequest(profile: RenderProfile = .stablePreview,
                                  derivative: ImageDerivativeSpec? = nil) throws -> HarbethRenderRequest {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let diagnostics = try makeDiagnostics(profile: profile, derivative: effectiveDerivative)
        let renderRecipe = try makeRenderRecipe(profile: profile, derivative: effectiveDerivative)
        let source = try resolvedPrimarySource()
        return HarbethRenderRequest(
            compilationSource: diagnostics.compilationSource,
            profile: profile,
            derivative: effectiveDerivative,
            source: source.descriptor,
            outputCachePolicy: resolvedCachePolicy,
            diagnostics: diagnostics,
            renderRecipe: renderRecipe,
            renderTexture: { try makeTexture(profile: profile, derivative: effectiveDerivative) },
            renderFrame: { metadata in
                try makeFrame(profile: profile, derivative: effectiveDerivative, metadata: metadata)
            }
        )
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

    private func resolvedPrimarySource() throws -> HarbethSource {
        switch self {
        case .source(let source):
            return source
        case .filters(let input, _), .kernel(let input, _, _), .cachePolicy(let input, _), .samplerDescriptor(let input, _):
            return try input.resolvedPrimarySource()
        case .recipe(let source, _, _):
            return source
        case .transition(let recipe):
            return recipe.from
        case .layerComposite(let recipe):
            return recipe.background
        }
    }
}

extension LayerCompositeRecipe {
    func makeRenderPlan(derivative: ImageDerivativeSpec? = nil) throws -> RenderPlan {
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
        )
    }

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
        try makeRenderPlan(derivative: derivative).diagnostics
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
                                            sourceColorSpace: ImageColorSpaceContract = .preserveInput,
                                            profile: RenderProfile) throws -> MTLTexture {
        var output = texture
        if let colorFilter = contract.colorSpace.makeTransferConversionFilter(from: sourceColorSpace) {
            output = try HarbethIO(element: output, filter: colorFilter)
                .configured(for: profile)
                .output()
        }
        let filters: [C7FilterProtocol]
        switch contract.alpha {
        case .premultiplied, .forcePremultiply:
            filters = [C7PremultiplyAlpha()]
        case .nonPremultiplied, .forceUnpremultiply:
            filters = [C7UnpremultiplyAlpha()]
        case .opaque, .preserveInput:
            filters = []
        }
        if filters.isEmpty == false {
            output = try HarbethIO(element: output, filters: filters)
                .configured(for: profile)
                .output()
        }
        if let targetPixelFormat = contract.pixelFormat.metalPixelFormat,
           output.pixelFormat != targetPixelFormat {
            var io = HarbethIO(element: output, filter: C7Brightness(brightness: 0))
                .configured(for: profile)
            io.bufferPixelFormat = targetPixelFormat
            io.createDestTexture = true
            output = try io.output()
        }
        return output
    }
}

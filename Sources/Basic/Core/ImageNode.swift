//
//  ImageNode.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal
import CoreGraphics
import CoreVideo
import CoreMedia

public protocol ImagePromise {
    var compilationSource: RenderCompilationSource { get }
    func makeTexture(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> MTLTexture
    func makeDiagnostics(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> RenderPlanDiagnostics
}

public indirect enum ImageNode {
    case source(ImageSource)
    case filters(input: ImageNode, filters: [C7FilterProtocol])
    case kernel(input: ImageNode, descriptor: KernelDescriptor, filter: C7FilterProtocol)
    case recipe(source: ImageSource, recipe: EditRecipe, mode: EditRecipeMode)
    case transition(TransitionRecipe)
    case layerComposite(LayerCompositeRecipe)
    case cachePolicy(input: ImageNode, policy: ImageCachePolicy)
    case samplerDescriptor(input: ImageNode, descriptor: ImageSamplerDescriptor)

    public static func source(_ source: ImageSource, filters: [C7FilterProtocol]) -> ImageNode {
        .filters(input: .source(source), filters: filters)
    }

    public static func texture(_ texture: MTLTexture) -> ImageNode {
        .source(.texture(texture))
    }

    public static func image(_ image: C7Image) -> ImageNode {
        .source(.image(image))
    }

    public static func cgImage(_ image: CGImage) -> ImageNode {
        .source(.cgImage(image))
    }

    public static func pixelBuffer(_ pixelBuffer: CVPixelBuffer) -> ImageNode {
        .source(.pixelBuffer(pixelBuffer))
    }

    public static func sampleBuffer(_ sampleBuffer: CMSampleBuffer) -> ImageNode {
        .source(.sampleBuffer(sampleBuffer))
    }

    public static func data(_ data: Data) -> ImageNode {
        .source(.data(data))
    }

    public static func asset(_ asset: ImageAsset) -> ImageNode {
        .source(.asset(asset))
    }

    public func withCachePolicy(_ policy: ImageCachePolicy) -> ImageNode {
        .cachePolicy(input: self, policy: policy)
    }

    public func withSamplerDescriptor(_ descriptor: ImageSamplerDescriptor) -> ImageNode {
        .samplerDescriptor(input: self, descriptor: descriptor)
    }

    public func applying(_ filter: C7FilterProtocol) -> ImageNode {
        .filters(input: self, filters: [filter])
    }

    public func applying(filters: [C7FilterProtocol]) -> ImageNode {
        .filters(input: self, filters: filters)
    }

    public func applying(_ invocation: KernelInvocation) -> ImageNode {
        .kernel(input: self, descriptor: invocation.descriptor, filter: invocation.executableFilter)
    }
}

extension ImageNode: ImagePromise {
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

    public func makeTexture(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
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

    private func makeTextureUncached(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> MTLTexture {
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
            try descriptor.validateCompatibility(
                with: filter,
                inputSize: C7Size(width: inputTexture.width, height: inputTexture.height)
            )
            let rendered = try HarbethIO(element: inputTexture, filter: filter)
                .configured(for: profile)
                .output()
            let contracted = try ImageNode.applyOutputContractIfNeeded(
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

    public func resolutionFingerprint(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) -> String {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        return [
            nodeFingerprint,
            "profile=\(profile)",
            effectiveDerivative.fingerprint,
            "cache=\(resolvedCachePolicy.rawValue)",
            "sampler=\(resolvedSamplerDescriptor.fingerprint)"
        ].joined(separator: " || ")
    }

    public func makeDiagnostics(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        try makeRenderPlan(profile: profile, derivative: derivative).diagnostics
    }

    public func makeImageGraph(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> ImageGraph {
        let builder = ImageGraphBuilder(profile: profile, derivative: derivative ?? profile.defaultDerivativeSpec)
        return try builder.build(from: self)
    }

    public func makeOptimizedImageGraph(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> ImageGraphOptimizationResult {
        ImageGraphOptimizer.optimize(try makeImageGraph(profile: profile, derivative: derivative))
    }

    public func makeDebugSnapshot(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderGraphDebugSnapshot {
        let optimization = try makeOptimizedImageGraph(profile: profile, derivative: derivative)
        let diagnostics = try makeRenderPlan(profile: profile, derivative: derivative).diagnostics
        return RenderGraphDebugSnapshot(
            graph: optimization.graph,
            diagnostics: diagnostics,
            optimizationDecisions: optimization.decisions
        )
    }

    public func makeDebugSnapshotJSONData(profile: RenderProfile = .stablePreview,
                                          derivative: ImageDerivativeSpec? = nil,
                                          prettyPrinted: Bool = false,
                                          sortedKeys: Bool = true) throws -> Data {
        try makeDebugSnapshot(profile: profile, derivative: derivative)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func makeDebugSnapshotJSONString(profile: RenderProfile = .stablePreview,
                                            derivative: ImageDerivativeSpec? = nil,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> String {
        try makeDebugSnapshot(profile: profile, derivative: derivative)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func makeAttachmentDebugPolicies(profile: RenderProfile = .stablePreview,
                                            derivative: ImageDerivativeSpec? = nil) throws -> [RenderOutputAttachmentDebugPolicy] {
        try makeDiagnostics(profile: profile, derivative: derivative).outputAttachmentDebugPolicies
    }

    public func makeRenderPlan(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderPlan {
        let optimization = try makeOptimizedImageGraph(profile: profile, derivative: derivative)
        switch self {
        case .source(let source):
            let texture = try source.makeTexture()
            return GraphCompiler.compile(
                filters: [],
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph,
                imageCachePolicy: source.cachePolicy,
                sourceDescriptor: source.descriptor,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            )
        case .filters(let input, let filters):
            let texture = try input.makeTexture(profile: profile, derivative: nil)
            return GraphCompiler.compile(
                filters: filters,
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph,
                sourceDescriptor: (try input.resolvedPrimarySource()).descriptor,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            )
        case .kernel(let input, let descriptor, let filter):
            let texture = try input.makeTexture(profile: profile, derivative: nil)
            try descriptor.validateCompatibility(
                with: filter,
                inputSize: C7Size(width: texture.width, height: texture.height)
            )
            return GraphCompiler.compile(
                filters: [filter],
                inputSize: C7Size(width: texture.width, height: texture.height),
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph,
                outputContract: descriptor.outputContract,
                sourceDescriptor: (try input.resolvedPrimarySource()).descriptor,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
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
                compilationSource: .transition,
                sourceDescriptor: recipe.from.descriptor,
                auxiliaryInputDescriptor: recipe.to.descriptor,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
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
                samplerDescriptor: plan.diagnostics.samplerDescriptor,
                sourceDescriptor: try input.resolvedPrimarySource().descriptor,
                inputColorConversionCount: plan.diagnostics.inputColorConversionCount,
                inputPixelFormatConversionCount: plan.diagnostics.inputPixelFormatConversionCount,
                inputAlphaConversionCount: plan.diagnostics.inputAlphaConversionCount,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
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
                samplerDescriptor: descriptor,
                sourceDescriptor: try input.resolvedPrimarySource().descriptor,
                inputColorConversionCount: plan.diagnostics.inputColorConversionCount,
                inputPixelFormatConversionCount: plan.diagnostics.inputPixelFormatConversionCount,
                inputAlphaConversionCount: plan.diagnostics.inputAlphaConversionCount,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            )
        }
    }

    public func makeRenderRecipe(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRecipe {
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

    /// 当 node 最终收敛到单个 `RenderProtocol` primitive 时，
    /// 直接导出多 attachment 的轻量分析 bundle。
    ///
    /// 这个入口不会把所有 node 都抬成 MRT runtime。
    /// 如果当前 node 不满足“最终一步是 render primitive”的条件，则返回 `nil`。
    public func makeAttachmentAnalysisBundle(profile: RenderProfile = .readbackQuality,
                                             bins: Int = 256,
                                             histogramHeight: Int = 64,
                                             preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle? {
        guard let bridge = try resolvedAttachmentAnalysisBridge(
            profile: profile
        ) else {
            return nil
        }
        return try bridge.filter.renderAttachmentAnalysisBundle(
            from: bridge.inputTexture,
            identifier: "ImageNode.AttachmentAnalysis.\(UUID().uuidString)",
            bins: bins,
            histogramHeight: histogramHeight,
            preferredMethod: preferredMethod
        )
    }

    public func makeRenderRequest(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRequest {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let diagnostics = try makeDiagnostics(profile: profile, derivative: effectiveDerivative)
        let renderRecipe = try makeRenderRecipe(profile: profile, derivative: effectiveDerivative)
        let source = try resolvedPrimarySource()
        return RenderRequest(
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

    fileprivate var resolvedCachePolicy: ImageCachePolicy {
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

    fileprivate var resolvedSamplerDescriptor: ImageSamplerDescriptor {
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

    fileprivate func resolvedPrimarySource() throws -> ImageSource {
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

    private func resolvedAttachmentAnalysisBridge(profile: RenderProfile) throws -> (inputTexture: MTLTexture, filter: any RenderProtocol)? {
        switch self {
        case .filters(let input, let filters):
            guard let finalFilter = filters.last as? any RenderProtocol else {
                return nil
            }
            let inputTexture: MTLTexture
            if filters.count > 1 {
                inputTexture = try ImageNode.filters(
                    input: input,
                    filters: Array(filters.dropLast())
                ).makeTexture(profile: profile, derivative: nil)
            } else {
                inputTexture = try input.makeTexture(profile: profile, derivative: nil)
            }
            return (inputTexture, finalFilter)
        case .kernel(let input, let descriptor, let filter):
            guard let renderFilter = filter as? any RenderProtocol else {
                return nil
            }
            let inputTexture = try input.makeTexture(profile: profile, derivative: nil)
            try descriptor.validateCompatibility(
                with: filter,
                inputSize: C7Size(width: inputTexture.width, height: inputTexture.height)
            )
            return (inputTexture, renderFilter)
        case .cachePolicy(let input, _):
            return try input.resolvedAttachmentAnalysisBridge(profile: profile)
        case .samplerDescriptor(let input, _):
            return try input.resolvedAttachmentAnalysisBridge(profile: profile)
        case .source, .recipe, .transition, .layerComposite:
            return nil
        }
    }
}

extension LayerCompositeRecipe {
    func makeRenderPlan(derivative: ImageDerivativeSpec? = nil) throws -> RenderPlan {
        let backgroundTexture = try background.makeTexture()
        let backgroundSize = C7Size(width: backgroundTexture.width, height: backgroundTexture.height)
        let placeholderTexture = backgroundTexture
        let filters = layers.flatMap { layer -> [C7FilterProtocol] in
            let composite = C7LayerComposite(
                layerTexture: placeholderTexture,
                mask: layer.mask,
                compositingMask: layer.compositingMask,
                normalizedFrame: layer.normalizedFrame,
                contentRegion: layer.contentRegion,
                opacity: layer.opacity,
                blendMode: layer.programmableBlend == nil ? layer.blendMode : .sourceOver,
                cornerRadius: layer.cornerRadius,
                cornerCurve: layer.cornerCurve,
                tintColor: layer.tintColor
            )
            guard let programmableBlend = layer.programmableBlend else {
                return [composite]
            }
            return [
                composite,
                C7ProgrammableBlend(
                    functionName: programmableBlend.functionName,
                    blendTexture: placeholderTexture,
                    intensity: programmableBlend.intensity,
                    capability: programmableBlend.capability,
                    librarySource: programmableBlend.librarySource,
                    functionConstants: programmableBlend.functionConstants
                )
            ]
        }
        return GraphCompiler.compile(
            filters: filters,
            inputSize: backgroundSize,
            profile: profile,
            derivative: derivative ?? self.derivative,
            compilationSource: .layerComposite,
            outputContract: outputContract,
            sourceDescriptor: background.descriptor
        )
    }

    func makeTexture(derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        var current = try background.makeTexture()
        guard layers.isEmpty == false else {
            return try resizeTextureIfNeeded(current, derivative: derivative ?? self.derivative)
        }

        for layer in layers {
            var layerTexture = try layer.content.makeTexture()
            var layerTransform = layer.transform
            if layer.rotation.truncatingRemainder(dividingBy: 360) != 0 {
                layerTransform.rotationDegrees += layer.rotation
            }
            if layer.flipOptions.horizontal {
                layerTransform.mirrorsHorizontally.toggle()
            }
            if layer.flipOptions.vertical {
                layerTransform.flipsVertically.toggle()
            }
            let layerFilters = layerTransform.makeFilters(
                inputSize: C7Size(width: layerTexture.width, height: layerTexture.height)
            ) + layer.filters
            if layerFilters.isEmpty == false {
                layerTexture = try HarbethIO(element: layerTexture, filters: layerFilters)
                    .configured(for: profile)
                    .output()
            }
            if let programmableBlend = layer.programmableBlend {
                let preparedLayer = try makeTransparentCanvas(matching: current)
                let layerCanvas = try HarbethIO(
                    element: preparedLayer,
                    filter: C7LayerComposite(
                        layerTexture: layerTexture,
                        mask: layer.mask,
                        compositingMask: layer.compositingMask,
                        normalizedFrame: layer.normalizedFrame,
                        contentRegion: layer.contentRegion,
                        opacity: layer.opacity,
                        blendMode: .sourceOver,
                        cornerRadius: layer.cornerRadius,
                        cornerCurve: layer.cornerCurve,
                        tintColor: layer.tintColor
                    )
                )
                .configured(for: profile)
                .output()
                current = try HarbethIO(
                    element: current,
                    filter: C7ProgrammableBlend(
                        functionName: programmableBlend.functionName,
                        blendTexture: layerCanvas,
                        intensity: programmableBlend.intensity,
                        capability: programmableBlend.capability,
                        librarySource: programmableBlend.librarySource,
                        functionConstants: programmableBlend.functionConstants
                    )
                )
                .configured(for: profile)
                .output()
                continue
            }
            current = try HarbethIO(
                element: current,
                filter: C7LayerComposite(
                    layerTexture: layerTexture,
                    mask: layer.mask,
                    compositingMask: layer.compositingMask,
                    normalizedFrame: layer.normalizedFrame,
                    contentRegion: layer.contentRegion,
                    opacity: layer.opacity,
                    blendMode: layer.blendMode,
                    cornerRadius: layer.cornerRadius,
                    cornerCurve: layer.cornerCurve,
                    tintColor: layer.tintColor
                )
            )
            .configured(for: profile)
            .output()
        }
        let contracted = try ImageNode.applyOutputContractIfNeeded(
            outputContract,
            to: current,
            profile: profile
        )
        return try resizeTextureIfNeeded(contracted, derivative: derivative ?? self.derivative)
    }

    func makeDiagnostics(derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        try makeRenderPlan(derivative: derivative).diagnostics
    }

    private func resizeTextureIfNeeded(_ texture: MTLTexture, derivative: ImageDerivativeSpec) throws -> MTLTexture {
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

    private func makeTransparentCanvas(matching texture: MTLTexture) throws -> MTLTexture {
        let canvas = try TextureLoader.makeTexture(width: texture.width, height: texture.height, options: [
            .texturePixelFormat: texture.pixelFormat,
            .textureUsage: texture.usage,
            .textureSampleCount: texture.sampleCount
        ], identifier: "LayerCompositeRecipe.TransparentCanvas")

        let bytesPerPixel: Int
        switch texture.pixelFormat {
        case .rgba8Unorm, .bgra8Unorm, .rgba8Snorm, .rgba8Unorm_srgb, .bgra8Unorm_srgb:
            bytesPerPixel = 4
        case .rgba16Float:
            bytesPerPixel = 8
        default:
            throw HarbethError.filterParameterInvalid("Unsupported programmable layer canvas pixel format: \(texture.pixelFormat)")
        }
        let bytesPerRow = texture.width * bytesPerPixel
        let zeroBytes = [UInt8](repeating: 0, count: texture.height * bytesPerRow)
        canvas.replace(
            region: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0,
            withBytes: zeroBytes,
            bytesPerRow: bytesPerRow
        )
        return canvas
    }
}

private final class ImageGraphBuilder {
    private let profile: RenderProfile
    private let derivative: ImageDerivativeSpec
    private var nodes: [ImageGraphNode] = []
    private var edges: [ImageGraphEdge] = []
    private var nextID: Int = 0

    init(profile: RenderProfile, derivative: ImageDerivativeSpec) {
        self.profile = profile
        self.derivative = derivative
    }

    func build(from node: ImageNode) throws -> ImageGraph {
        let rootNodeID = try append(node)
        return ImageGraph(
            nodes: nodes,
            edges: edges,
            rootNodeID: rootNodeID,
            profile: profile,
            derivative: derivative
        )
    }

    private func append(_ node: ImageNode) throws -> ImageGraphNodeID {
        switch node {
        case .source(let source):
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .source,
                    name: "Source.\(source.kindName)",
                    cachePolicy: source.cachePolicy,
                    samplerDescriptor: .default,
                    sourceKind: source.kindName,
                    filterCount: 0,
                    fingerprint: source.descriptor.fingerprint
                )
            )
            return nodeID
        case .filters(let input, let filters):
            let inputID = try append(input)
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .filters,
                    name: "Filters",
                    cachePolicy: node.resolvedCachePolicy,
                    samplerDescriptor: node.resolvedSamplerDescriptor,
                    sourceKind: try node.resolvedPrimarySource().kindName,
                    filterCount: filters.count,
                    fingerprint: node.resolutionFingerprint(profile: profile, derivative: derivative)
                )
            )
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            return nodeID
        case .kernel(let input, let descriptor, _):
            let inputID = try append(input)
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .kernel,
                    name: descriptor.filterName,
                    cachePolicy: node.resolvedCachePolicy,
                    samplerDescriptor: node.resolvedSamplerDescriptor,
                    sourceKind: try node.resolvedPrimarySource().kindName,
                    filterCount: 1,
                    fingerprint: descriptor.fingerprint
                )
            )
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            return nodeID
        case .recipe(let source, let recipe, let mode):
            let sourceID = try append(.source(source))
            let nodeID = allocateID()
            let contract = recipe.contract(for: mode)
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .recipe,
                    name: "EditRecipe.\(mode.rawValue)",
                    cachePolicy: node.resolvedCachePolicy,
                    samplerDescriptor: node.resolvedSamplerDescriptor,
                    sourceKind: source.kindName,
                    filterCount: recipe.makeFilterChain(inputSize: C7Size(width: 1, height: 1)).count,
                    fingerprint: "profile=\(contract.profile)|\(contract.derivative.fingerprint)"
                )
            )
            edges.append(ImageGraphEdge(from: sourceID, to: nodeID))
            return nodeID
        case .transition(let recipe):
            let fromID = try append(.source(recipe.from))
            let toID = try append(.source(recipe.to))
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .transition,
                    name: String(describing: type(of: recipe.kernel)),
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: recipe.from.kindName,
                    filterCount: 1,
                    fingerprint: [
                        recipe.from.resolutionFingerprint,
                        recipe.to.resolutionFingerprint,
                        recipe.kernel.fingerprint,
                        "progress=\(recipe.progress)"
                    ].joined(separator: "|")
                )
            )
            edges.append(ImageGraphEdge(from: fromID, to: nodeID, label: "from"))
            edges.append(ImageGraphEdge(from: toID, to: nodeID, label: "to"))
            return nodeID
        case .layerComposite(let recipe):
            let backgroundID = try append(.source(recipe.background))
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .layerComposite,
                    name: "LayerComposite",
                    cachePolicy: .transient,
                    samplerDescriptor: .default,
                    sourceKind: recipe.background.kindName,
                    filterCount: recipe.layers.count,
                    fingerprint: recipe.fingerprint
                )
            )
            edges.append(ImageGraphEdge(from: backgroundID, to: nodeID, label: "background"))
            return nodeID
        case .cachePolicy(let input, let policy):
            let inputID = try append(input)
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .cachePolicy,
                    name: "CachePolicy.\(policy.rawValue)",
                    cachePolicy: policy,
                    samplerDescriptor: node.resolvedSamplerDescriptor,
                    sourceKind: try node.resolvedPrimarySource().kindName,
                    filterCount: 0,
                    fingerprint: node.resolutionFingerprint(profile: profile, derivative: derivative)
                )
            )
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            return nodeID
        case .samplerDescriptor(let input, let descriptor):
            let inputID = try append(input)
            let nodeID = allocateID()
            nodes.append(
                ImageGraphNode(
                    id: nodeID,
                    kind: .samplerDescriptor,
                    name: "SamplerDescriptor",
                    cachePolicy: node.resolvedCachePolicy,
                    samplerDescriptor: descriptor,
                    sourceKind: try node.resolvedPrimarySource().kindName,
                    filterCount: 0,
                    fingerprint: descriptor.fingerprint
                )
            )
            edges.append(ImageGraphEdge(from: inputID, to: nodeID))
            return nodeID
        }
    }

    private func allocateID() -> ImageGraphNodeID {
        defer { nextID += 1 }
        return ImageGraphNodeID(rawValue: nextID)
    }
}

extension ImageNode {
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
        case .opaque:
            filters = [C7ForceOpaqueAlpha()]
        case .preserveInput:
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

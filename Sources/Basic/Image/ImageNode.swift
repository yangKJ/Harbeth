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

protocol ImagePromise {
    var compilationSource: RenderCompilationSource { get }
    func makeTexture(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> MTLTexture
    func makeDiagnostics(profile: RenderProfile, derivative: ImageDerivativeSpec?) throws -> RenderPlanDiagnostics
}

indirect enum ImageNodeStorage {
    case source(ImageSource)
    case filters(input: ImageNode, filters: [C7FilterProtocol])
    case kernel(input: ImageNode, descriptor: KernelDescriptor, filter: C7FilterProtocol)
    case recipe(source: ImageSource, recipe: EditRecipe, mode: EditRecipeMode)
    case edit(input: ImageNode, recipe: EditRecipe, mode: EditRecipeMode)
    case transition(TransitionRecipe)
    case layerComposite(LayerCompositeRecipe)
    case cachePolicy(input: ImageNode, policy: ImageCachePolicy)
    case samplerDescriptor(input: ImageNode, descriptor: ImageSamplerDescriptor)
}

private final class BoxedTexture {
    let texture: MTLTexture
    init(texture: MTLTexture) { self.texture = texture }
}

public struct ImageNode {
    let storage: ImageNodeStorage

    init(storage: ImageNodeStorage) {
        self.storage = storage
    }

    static func filters(input: ImageNode, filters: [C7FilterProtocol]) -> ImageNode {
        ImageNode(storage: .filters(input: input, filters: filters))
    }

    static func kernel(input: ImageNode, descriptor: KernelDescriptor, filter: C7FilterProtocol) -> ImageNode {
        ImageNode(storage: .kernel(input: input, descriptor: descriptor, filter: filter))
    }
    
    func applying(_ invocation: KernelInvocation) -> ImageNode {
        ImageNode(storage: .kernel(input: self, descriptor: invocation.descriptor, filter: invocation.executableFilter))
    }
}

extension ImageNode {
    public static func source(_ source: ImageSource) -> ImageNode {
        ImageNode(storage: .source(source))
    }

    public static func recipe(source: ImageSource, recipe: EditRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        ImageNode.source(source).editing(recipe, mode: mode)
    }

    public static func layerComposite(_ recipe: LayerCompositeRecipe) -> ImageNode {
        ImageNode(storage: .layerComposite(recipe))
    }

    public static func texture(_ texture: MTLTexture) -> ImageNode {
        .source(ImageSource.texture(texture))
    }

    public static func image(_ image: C7Image) -> ImageNode {
        .source(ImageSource.image(image))
    }

    public static func cgImage(_ image: CGImage) -> ImageNode {
        .source(ImageSource.cgImage(image))
    }

    public static func pixelBuffer(_ pixelBuffer: CVPixelBuffer) -> ImageNode {
        .source(ImageSource.pixelBuffer(pixelBuffer))
    }

    public static func sampleBuffer(_ sampleBuffer: CMSampleBuffer) -> ImageNode {
        .source(ImageSource.sampleBuffer(sampleBuffer))
    }

    public static func data(_ data: Data) -> ImageNode {
        .source(ImageSource.data(data))
    }

    public static func asset(_ asset: ImageAsset) -> ImageNode {
        .source(ImageSource.asset(asset))
    }

    public func withCachePolicy(_ policy: ImageCachePolicy) -> ImageNode {
        ImageNode(storage: .cachePolicy(input: self, policy: policy))
    }

    public func withSamplerDescriptor(_ descriptor: ImageSamplerDescriptor) -> ImageNode {
        ImageNode(storage: .samplerDescriptor(input: self, descriptor: descriptor))
    }

    public func applying(_ filter: C7FilterProtocol) -> ImageNode {
        ImageNode(storage: .filters(input: self, filters: [filter]))
    }

    public func applying(filters: [C7FilterProtocol]) -> ImageNode {
        ImageNode(storage: .filters(input: self, filters: filters))
    }

    public func applyingWithContract(_ filter: C7FilterProtocol, inputSize: C7Size? = nil) -> ImageNode {
        let descriptor = filter.kernelDescriptor(inputSize: inputSize)
        let invocation = descriptor.makeInvocation(filter: filter, inputSize: inputSize)
        return applying(invocation)
    }

    public func applying(pluginOutput: PluginOutput, mode: EditRecipeMode = .preview) throws -> ImageNode {
        switch pluginOutput {
        case .texture, .image, .cgImage, .pixelBuffer, .sampleBuffer:
            return ImageNode.source(try pluginOutput.makeImageSource())
        case .filters(let filters):
            return applying(filters: filters)
        case .editRecipe(let recipe):
            return editing(recipe, mode: mode)
        case .localEffect(let localEffect):
            return applying(localEffect: localEffect, mode: mode)
        case .layerComposite(let recipe):
            return ImageNode.layerComposite(recipe)
        }
    }

    public func applying<P: Plugin>(plugin: P,
                                    profile: RenderProfile = .stablePreview,
                                    derivative: ImageDerivativeSpec? = nil,
                                    mode: EditRecipeMode = .preview) throws -> ImageNode {
        let frame = try makeFrame(profile: profile, derivative: derivative)
        let context = PluginContext(
            profile: profile,
            identifier: plugin.pluginIdentifier,
            metadata: [
                "pluginIdentifier": plugin.pluginIdentifier,
                "pluginBoundaryKind": plugin.capability.kind.rawValue
            ]
        )
        let output = try plugin.makeOutput(frame: frame, context: context)
        return try applying(pluginOutput: output, mode: mode)
    }

    public func makeFrame(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil, metadata: [String: String] = [:]) throws -> RenderedFrame {
        let monitoringIdentifier = self.monitoringIdentifier
        let monitorEnabled = Shared.shared.enablePerformanceMonitor
        if monitorEnabled {
            Shared.shared.performanceMonitor?.beginMonitoring(monitoringIdentifier)
        }
        defer {
            if monitorEnabled {
                Shared.shared.performanceMonitor?.endMonitoring(monitoringIdentifier)
            }
        }

        let texture = try makeTexture(
            profile: profile,
            derivative: derivative,
            executionIdentifier: monitoringIdentifier
        )
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let renderRecipe = try makeRenderRecipe(profile: profile, derivative: effectiveDerivative)
        let diagnostics = try makeDiagnostics(profile: profile, derivative: effectiveDerivative)
        let primarySource = try resolvedPrimarySource()
        let colorSpace = resolvedFrameColorSpace(for: primarySource, outputColorSpace: diagnostics.outputColorSpace)
        let previewHostStrategy = resolvedPreviewHostStrategy(
            source: primarySource,
            renderedTexture: texture,
            renderRecipe: renderRecipe
        )
        if monitorEnabled {
            Shared.shared.performanceMonitor?.recordPreviewHostStrategy(monitoringIdentifier, strategy: previewHostStrategy)
        }
        let previewHostPayload = makePreviewHostPayload(
            source: primarySource,
            renderedTexture: texture,
            renderRecipe: renderRecipe
        )
        var renderedMetadata = metadata
        renderedMetadata["filterChainFingerprint"] = FilterChainRecipe(filters: renderRecipe.filters).fingerprint
        let token = FrameRenderToken(identifier: monitoringIdentifier, generation: FrameGeneration.next())
        return RenderedFrame(
            texture: texture,
            colorSpace: colorSpace,
            sourceDescriptor: primarySource.descriptor,
            derivative: effectiveDerivative,
            resolvedOutputSize: C7Size(width: texture.width, height: texture.height),
            renderIntent: effectiveDerivative.renderIntent,
            sourceTier: primarySource.sourceTier,
            alphaType: primarySource.alphaType,
            cachePolicy: resolvedCachePolicy,
            semantic: effectiveDerivative.semantic,
            orientation: primarySource.orientation,
            profile: profile,
            token: token,
            metadata: renderedMetadata,
            previewHostPayload: previewHostPayload
        )
    }

    public func transmitFrame(profile: RenderProfile = .stablePreview,
                              derivative: ImageDerivativeSpec? = nil,
                              metadata: [String: String] = [:],
                              complete: @escaping (Result<RenderedFrame, HarbethError>) -> Void) {
        do {
            complete(.success(try makeFrame(profile: profile, derivative: derivative, metadata: metadata)))
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }

    public func startRenderFrameTask(profile: RenderProfile = .stablePreview,
                                     derivative: ImageDerivativeSpec? = nil,
                                     metadata: [String: String] = [:]) throws -> RenderTask<RenderedFrame> {
        let frame = try makeFrame(profile: profile, derivative: derivative, metadata: metadata)
        let diagnostics = try makeDiagnostics(profile: profile, derivative: derivative ?? profile.defaultDerivativeSpec)
        return .completed(identifier: frame.identifier, output: frame, diagnostics: diagnostics)
    }

    public func makeTexture(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        try makeTexture(profile: profile, derivative: derivative, executionIdentifier: nil)
    }

    private func makeTexture(profile: RenderProfile, derivative: ImageDerivativeSpec?, executionIdentifier: String?) throws -> MTLTexture {
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
        let texture = try makeTextureUncached(
            profile: profile,
            derivative: derivative,
            samplerDescriptor: .default,
            executionIdentifier: executionIdentifier
        )
        if effectiveCachePolicy == .persistent {
            Shared.shared.defaultContext.storeResolvedTexture(texture, for: fingerprint)
        }
        return texture
    }

    public func makeDebugSnapshot(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderGraphDebugSnapshot {
        let plan = try makeRenderPlan(profile: profile, derivative: derivative)
        let graph = try plan.imageGraph ?? makeImageGraph(profile: profile, derivative: derivative)
        let renderRecipe = try makeRenderRecipe(profile: profile, derivative: derivative)
        return RenderGraphDebugSnapshot(
            graph: graph,
            diagnostics: plan.diagnostics,
            optimizationDecisions: plan.diagnostics.graphOptimizationDecisions,
            renderRecipe: renderRecipe
        )
    }

    public func makeImageGraph(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> ImageGraph {
        let builder = ImageGraphBuilder(profile: profile, derivative: derivative ?? profile.defaultDerivativeSpec)
        return try builder.build(from: self)
    }

    public func makeDiagnostics(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        try makeRenderPlan(profile: profile, derivative: derivative).diagnostics
    }

    public func makeAttachmentDebugPolicies(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> [RenderOutputAttachmentDebugPolicy] {
        try makeDiagnostics(profile: profile, derivative: derivative).outputAttachmentDebugPolicies
    }

    public func makeHistogram(profile: RenderProfile = .readbackQuality,
                              derivative: ImageDerivativeSpec? = nil,
                              channel: TextureHistogramChannel = .luminance,
                              bins: Int = 256,
                              region: MTLRegion? = nil,
                              mask: MaskDescriptor? = nil,
                              luminanceRange: TextureLuminanceRange? = nil,
                              colorRange: TextureColorRange? = nil,
                              coverageThreshold: Float = 0.5,
                              preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try makeFrame(profile: profile, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    public func makeHistogram(profile: RenderProfile = .readbackQuality,
                              derivative: ImageDerivativeSpec? = nil,
                              channel: TextureHistogramChannel = .luminance,
                              bins: Int = 256,
                              scope: TextureAnalysisScope,
                              preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try makeFrame(profile: profile, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeHistogramAttachment(profile: RenderProfile = .readbackQuality,
                                        derivative: ImageDerivativeSpec? = nil,
                                        channel: TextureHistogramChannel = .luminance,
                                        bins: Int = 256,
                                        height: Int = 64,
                                        region: MTLRegion? = nil,
                                        mask: MaskDescriptor? = nil,
                                        luminanceRange: TextureLuminanceRange? = nil,
                                        colorRange: TextureColorRange? = nil,
                                        coverageThreshold: Float = 0.5,
                                        preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedHistogramAttachment? {
        try makeFrame(profile: profile, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    public func makeHistogramAttachment(profile: RenderProfile = .readbackQuality,
                                        derivative: ImageDerivativeSpec? = nil,
                                        channel: TextureHistogramChannel = .luminance,
                                        bins: Int = 256,
                                        height: Int = 64,
                                        scope: TextureAnalysisScope,
                                        preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedHistogramAttachment? {
        try makeFrame(profile: profile, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeAnalysisBundle(profile: RenderProfile = .readbackQuality,
                                   derivative: ImageDerivativeSpec? = nil,
                                   channel: TextureHistogramChannel = .luminance,
                                   bins: Int = 256,
                                   histogramHeight: Int = 64,
                                   region: MTLRegion? = nil,
                                   mask: MaskDescriptor? = nil,
                                   luminanceRange: TextureLuminanceRange? = nil,
                                   colorRange: TextureColorRange? = nil,
                                   coverageThreshold: Float = 0.5,
                                   preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle {
        let frame = try makeFrame(profile: profile, derivative: derivative)
        return RenderedAnalysisBundle.makeRegionBundle(
            frame: frame,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            preferredMethod: preferredMethod,
            attachmentDebugPolicies: [RenderOutputAttachmentContract(index: 0).debugPolicy]
        )
    }

    public func makeAnalysisBundle(profile: RenderProfile = .readbackQuality,
                                   derivative: ImageDerivativeSpec? = nil,
                                   channel: TextureHistogramChannel = .luminance,
                                   bins: Int = 256,
                                   histogramHeight: Int = 64,
                                   scope: TextureAnalysisScope,
                                   preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle {
        let frame = try makeFrame(profile: profile, derivative: derivative)
        return RenderedAnalysisBundle.makeScopeBundle(
            frame: frame,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod,
            attachmentDebugPolicies: [RenderOutputAttachmentContract(index: 0).debugPolicy]
        )
    }

    public func makeStatistics(profile: RenderProfile = .readbackQuality,
                               derivative: ImageDerivativeSpec? = nil,
                               region: MTLRegion? = nil,
                               mask: MaskDescriptor? = nil,
                               luminanceRange: TextureLuminanceRange? = nil,
                               colorRange: TextureColorRange? = nil,
                               coverageThreshold: Float = 0.5) throws -> TextureStatistics? {
        try makeFrame(profile: profile, derivative: derivative).makeStatistics(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeStatistics(profile: RenderProfile = .readbackQuality,
                               derivative: ImageDerivativeSpec? = nil,
                               scope: TextureAnalysisScope) throws -> TextureStatistics? {
        try makeFrame(profile: profile, derivative: derivative).makeStatistics(scope: scope)
    }

    public func makeColorProbe(profile: RenderProfile = .readbackQuality,
                               derivative: ImageDerivativeSpec? = nil,
                               x: Int,
                               y: Int,
                               radius: Int = 0,
                               mask: MaskDescriptor? = nil,
                               luminanceRange: TextureLuminanceRange? = nil,
                               colorRange: TextureColorRange? = nil,
                               coverageThreshold: Float = 0.5) throws -> TextureColorProbe? {
        try makeFrame(profile: profile, derivative: derivative).makeColorProbe(
            x: x,
            y: y,
            radius: radius,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeColorProbe(profile: RenderProfile = .readbackQuality,
                               derivative: ImageDerivativeSpec? = nil,
                               region: MTLRegion? = nil,
                               mask: MaskDescriptor? = nil,
                               luminanceRange: TextureLuminanceRange? = nil,
                               colorRange: TextureColorRange? = nil,
                               coverageThreshold: Float = 0.5) throws -> TextureColorProbe? {
        try makeFrame(profile: profile, derivative: derivative).makeColorProbe(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeColorProbe(profile: RenderProfile = .readbackQuality,
                               derivative: ImageDerivativeSpec? = nil,
                               scope: TextureAnalysisScope) throws -> TextureColorProbe? {
        try makeFrame(profile: profile, derivative: derivative).makeColorProbe(scope: scope)
    }

    public func makeMaskTexture(profile: RenderProfile = .readbackQuality,
                                derivative: ImageDerivativeSpec? = nil,
                                scope: TextureAnalysisScope,
                                pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try makeFrame(profile: profile, derivative: derivative).makeMaskTexture(
            scope: scope,
            pixelFormat: pixelFormat
        )
    }

    public func makeMaskDescriptor(profile: RenderProfile = .readbackQuality,
                                   derivative: ImageDerivativeSpec? = nil,
                                   scope: TextureAnalysisScope,
                                   component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0,
                                   pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try makeFrame(profile: profile, derivative: derivative).makeMaskDescriptor(
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }

    public func makeAttachmentSet(profile: RenderProfile = .readbackQuality) throws -> RenderedAttachmentSet? {
        guard let bridge = try resolvedAttachmentAnalysisBridge(profile: profile) else {
            return nil
        }
        return try bridge.filter.renderAttachmentSet(
            from: bridge.inputTexture,
            identifier: "ImageNode.AttachmentSet.\(UUID().uuidString)"
        )
    }

    public func makeAttachment(profile: RenderProfile = .readbackQuality,
                               semantic: RenderOutputAttachmentSemantic) throws -> RenderedAttachment? {
        try makeAttachmentSet(profile: profile)?.attachment(for: semantic)
    }

    public func makeAttachmentAnalysis(profile: RenderProfile = .readbackQuality,
                                       semantic: RenderOutputAttachmentSemantic,
                                       channel: TextureHistogramChannel? = nil,
                                       bins: Int = 256,
                                       histogramHeight: Int = 64,
                                       region: MTLRegion? = nil,
                                       preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysis? {
        try makeAttachmentAnalysisBundle(
            profile: profile,
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            preferredMethod: preferredMethod
        )?.analysis(for: semantic)
    }

    public func makeAttachmentAnalysis(profile: RenderProfile = .readbackQuality,
                                       semantic: RenderOutputAttachmentSemantic,
                                       channel: TextureHistogramChannel? = nil,
                                       bins: Int = 256,
                                       histogramHeight: Int = 64,
                                       scope: TextureAnalysisScope,
                                       preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysis? {
        try makeAttachmentAnalysisBundle(
            profile: profile,
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod
        )?.analysis(for: semantic)
    }

    public func makeAttachmentHistogram(profile: RenderProfile = .readbackQuality,
                                        semantic: RenderOutputAttachmentSemantic,
                                        channel: TextureHistogramChannel? = nil,
                                        bins: Int = 256,
                                        region: MTLRegion? = nil,
                                        preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try makeAttachmentSet(profile: profile)?.makeHistogram(
            for: semantic,
            channel: channel,
            bins: bins,
            region: region,
            preferredMethod: preferredMethod
        )
    }

    public func makeAttachmentHistogram(profile: RenderProfile = .readbackQuality,
                                        semantic: RenderOutputAttachmentSemantic,
                                        channel: TextureHistogramChannel? = nil,
                                        bins: Int = 256,
                                        scope: TextureAnalysisScope,
                                        preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try makeAttachmentSet(profile: profile)?.makeHistogram(
            for: semantic,
            channel: channel,
            bins: bins,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeAttachmentStatistics(profile: RenderProfile = .readbackQuality,
                                         semantic: RenderOutputAttachmentSemantic,
                                         region: MTLRegion? = nil,
                                         mask: MaskDescriptor? = nil,
                                         luminanceRange: TextureLuminanceRange? = nil,
                                         colorRange: TextureColorRange? = nil,
                                         coverageThreshold: Float = 0.5) throws -> TextureStatistics? {
        try makeAttachmentSet(profile: profile)?.makeStatistics(
            for: semantic,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeAttachmentStatistics(profile: RenderProfile = .readbackQuality,
                                         semantic: RenderOutputAttachmentSemantic,
                                         scope: TextureAnalysisScope) throws -> TextureStatistics? {
        try makeAttachmentSet(profile: profile)?.makeStatistics(for: semantic, scope: scope)
    }

    public func makeAttachmentColorProbe(profile: RenderProfile = .readbackQuality,
                                         semantic: RenderOutputAttachmentSemantic,
                                         region: MTLRegion? = nil,
                                         mask: MaskDescriptor? = nil,
                                         luminanceRange: TextureLuminanceRange? = nil,
                                         colorRange: TextureColorRange? = nil,
                                         coverageThreshold: Float = 0.5) throws -> TextureColorProbe? {
        try makeAttachmentSet(profile: profile)?.makeColorProbe(
            for: semantic,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func makeAttachmentColorProbe(profile: RenderProfile = .readbackQuality,
                                         semantic: RenderOutputAttachmentSemantic,
                                         scope: TextureAnalysisScope) throws -> TextureColorProbe? {
        try makeAttachmentSet(profile: profile)?.makeColorProbe(for: semantic, scope: scope)
    }

    public func makeAttachmentMaskTexture(profile: RenderProfile = .readbackQuality,
                                          semantic: RenderOutputAttachmentSemantic,
                                          scope: TextureAnalysisScope,
                                          pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture? {
        try makeAttachmentSet(profile: profile)?.makeMaskTexture(
            for: semantic,
            scope: scope,
            pixelFormat: pixelFormat
        )
    }

    public func makeAttachmentMaskDescriptor(profile: RenderProfile = .readbackQuality,
                                             semantic: RenderOutputAttachmentSemantic,
                                             scope: TextureAnalysisScope,
                                             component: MaskComponent = .red,
                                             blendMode: MaskBlendMode = .mix,
                                             invert: Bool = false,
                                             featherPolicy: MaskFeatherPolicy = .none,
                                             opacity: Float = 1.0,
                                             pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try makeAttachmentSet(profile: profile)?.makeMaskDescriptor(
            for: semantic,
            scope: scope,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: pixelFormat
        )
    }

    public func makeAttachmentAnalysisBundle(profile: RenderProfile = .readbackQuality,
                                             bins: Int = 256,
                                             histogramHeight: Int = 64,
                                             region: MTLRegion? = nil,
                                             preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle? {
        guard let bridge = try resolvedAttachmentAnalysisBridge(profile: profile) else {
            return nil
        }
        return try bridge.filter.renderAttachmentAnalysisBundle(
            from: bridge.inputTexture,
            identifier: "ImageNode.AttachmentAnalysis.\(UUID().uuidString)",
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            preferredMethod: preferredMethod
        )
    }

    public func makeAttachmentAnalysisBundle(profile: RenderProfile = .readbackQuality,
                                             bins: Int = 256,
                                             histogramHeight: Int = 64,
                                             scope: TextureAnalysisScope,
                                             preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle? {
        guard let bridge = try resolvedAttachmentAnalysisBridge(profile: profile) else {
            return nil
        }
        return try bridge.filter.renderAttachmentAnalysisBundle(
            from: bridge.inputTexture,
            identifier: "ImageNode.AttachmentAnalysis.\(UUID().uuidString)",
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func makeRenderRequest(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRequest {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let diagnostics = try makeDiagnostics(profile: profile, derivative: effectiveDerivative)
        let renderRecipe = try makeRenderRecipe(profile: profile, derivative: effectiveDerivative)
        let source = try resolvedPrimarySource()
        let attachmentPolicies = diagnostics.outputAttachmentDebugPolicies
        return RenderRequest.makeFrameBackedRequest(
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
            },
            attachmentDebugPolicies: attachmentPolicies,
            renderAttachmentSet: {
                try makeAttachmentSet(profile: profile)
            },
            renderAttachmentAnalysisBundle: { bins, histogramHeight, region, preferredMethod in
                try makeAttachmentAnalysisBundle(
                    profile: profile,
                    bins: bins,
                    histogramHeight: histogramHeight,
                    region: region,
                    preferredMethod: preferredMethod
                )
            },
            renderAttachmentAnalysisScopeBundle: { bins, histogramHeight, scope, preferredMethod in
                try makeAttachmentAnalysisBundle(
                    profile: profile,
                    bins: bins,
                    histogramHeight: histogramHeight,
                    scope: scope,
                    preferredMethod: preferredMethod
                )
            }
        )
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ImageNode {
    public func makeFrameAsync(profile: RenderProfile = .stablePreview,
                               derivative: ImageDerivativeSpec? = nil,
                               metadata: [String: String] = [:]) async throws -> RenderedFrame {
        try await withCheckedThrowingContinuation { continuation in
            transmitFrame(profile: profile, derivative: derivative, metadata: metadata) { result in
                switch result {
                case .success(let frame):
                    continuation.resume(returning: frame)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension ImageNode: ImagePromise {
    var compilationSource: RenderCompilationSource {
        switch storage {
        case .source:
            return .nodeGraph
        case .filters(let input, _):
            return input.compilationSource
        case .kernel(let input, _, _):
            return input.compilationSource
        case .recipe:
            return .editRecipe
        case .edit:
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

    private func makeTextureUncached(profile: RenderProfile,
                                     derivative: ImageDerivativeSpec?,
                                     samplerDescriptor: ImageSamplerDescriptor,
                                     executionIdentifier: String?) throws -> MTLTexture {
        switch storage {
        case .source(let source):
            let texture = try source.makeTexture()
            return try resizeTextureIfNeeded(
                texture,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                profile: profile,
                executionIdentifier: executionIdentifier
            )
        case .filters(let input, let filters):
            let inputTexture = try input.makeTextureUncached(
                profile: profile,
                derivative: nil,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier
            )
            guard filters.isEmpty == false else {
                return try resizeTextureIfNeeded(
                    inputTexture,
                    derivative: derivative ?? profile.defaultDerivativeSpec,
                    profile: profile,
                    executionIdentifier: executionIdentifier
                )
            }
            let rendered = try HarbethIO(
                element: inputTexture,
                filters: SamplerExecutionAdapter.adapt(filters: filters, samplerDescriptor: samplerDescriptor),
                identifier: executionIdentifier ?? monitoringIdentifier
            ).configured(for: profile).output()
            return try resizeTextureIfNeeded(
                rendered,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                profile: profile,
                executionIdentifier: executionIdentifier
            )
        case .kernel(let input, let descriptor, let filter):
            let inputTexture = try input.makeTextureUncached(
                profile: profile,
                derivative: nil,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier
            )
            try descriptor.validateCompatibility(
                with: filter,
                inputSize: C7Size(width: inputTexture.width, height: inputTexture.height)
            )
            let rendered = try HarbethIO(
                element: inputTexture,
                filter: SamplerExecutionAdapter.adapt(filter: filter, samplerDescriptor: samplerDescriptor),
                identifier: executionIdentifier ?? monitoringIdentifier
            ).configured(for: profile).output()
            let contracted = try ImageNode.applyOutputContractIfNeeded(
                descriptor.outputContract,
                to: rendered,
                sourceColorSpace: descriptor.inputColorSpace,
                sourceAlphaType: descriptor.outputContract.inputAlphaExpectation.expectedAlphaType,
                profile: profile,
                identifier: executionIdentifier ?? monitoringIdentifier
            )
            return try resizeTextureIfNeeded(
                contracted,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                profile: profile,
                executionIdentifier: executionIdentifier
            )
        case .recipe(let source, let recipe, let mode):
            return try FrameRenderer(
                source: source,
                recipe: recipe,
                mode: mode,
                identifier: executionIdentifier ?? monitoringIdentifier,
                derivative: derivative,
                samplerDescriptor: samplerDescriptor
            ).renderTexture()
        case .edit(let input, let recipe, let mode):
            let inputTexture = try input.makeTextureUncached(
                profile: profile,
                derivative: nil,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier
            )
            return try FrameRenderer(
                source: .texture(inputTexture),
                recipe: recipe,
                mode: mode,
                identifier: executionIdentifier ?? monitoringIdentifier,
                derivative: derivative,
                samplerDescriptor: samplerDescriptor
            ).renderTexture()
        case .transition(let recipe):
            return try FrameRenderer(
                transitionRecipe: recipe,
                profile: profile,
                derivative: derivative,
                identifier: executionIdentifier ?? monitoringIdentifier,
                samplerDescriptor: samplerDescriptor
            ).renderTexture()
        case .layerComposite(let recipe):
            return try recipe.makeTexture(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier ?? monitoringIdentifier
            )
        case .cachePolicy(let input, _):
            return try input.makeTextureUncached(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: samplerDescriptor,
                executionIdentifier: executionIdentifier
            )
        case .samplerDescriptor(let input, let descriptor):
            return try input.makeTextureUncached(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: descriptor,
                executionIdentifier: executionIdentifier
            )
        }
    }

    func resolutionFingerprint(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) -> String {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        return [
            nodeFingerprint,
            "profile=\(profile)",
            effectiveDerivative.fingerprint,
            "cache=\(resolvedCachePolicy.rawValue)",
            "sampler=\(resolvedSamplerDescriptor.fingerprint)"
        ].joined(separator: " || ")
    }

    func makeOptimizedImageGraph(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> ImageGraphOptimizationResult {
        ImageGraphOptimizer.optimize(try makeImageGraph(profile: profile, derivative: derivative))
    }

    func makeRenderPlan(profile: RenderProfile = .stablePreview,
                        derivative: ImageDerivativeSpec? = nil,
                        samplerDescriptorOverride: ImageSamplerDescriptor? = nil) throws -> RenderPlan {
        let activeSamplerDescriptor = samplerDescriptorOverride ?? resolvedSamplerDescriptor
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let cacheKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: nodeFingerprint,
            profile: profile,
            derivative: effectiveDerivative,
            samplerDescriptor: activeSamplerDescriptor
        )
        if let cached = Shared.shared.defaultContext.cachedRenderPlan(for: cacheKey) {
            Shared.shared.performanceMonitor?.recordPipelineCacheLookup("renderPlan", hit: true)
            return cached
        }
        Shared.shared.performanceMonitor?.recordPipelineCacheLookup("renderPlan", hit: false)
        let optimization = try makeOptimizedImageGraph(profile: profile, derivative: derivative)
        var plan: RenderPlan
        switch storage {
        case .source(let source):
            let inputSize: C7Size
            if let size = source.resolvedSizeHint {
                inputSize = size
            } else {
                let texture = try source.makeTexture()
                inputSize = C7Size(width: texture.width, height: texture.height)
            }
            plan = GraphCompiler.compile(
                filters: [],
                inputSize: inputSize,
                profile: profile,
                derivative: derivative ?? profile.defaultDerivativeSpec,
                compilationSource: .nodeGraph,
                imageCachePolicy: source.cachePolicy,
                samplerDescriptor: activeSamplerDescriptor,
                sourceDescriptor: source.descriptor,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            )
        case .filters(let input, let filters):
            switch input.storage {
            case .recipe(let source, let recipe, let mode):
                plan = try makeWrappedEditRenderPlan(
                    source: source,
                    recipe: recipe,
                    mode: mode,
                    extraFilters: filters,
                    profile: profile,
                    derivative: derivative,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: source.descriptor,
                    optimization: optimization
                )
            case .edit(let upstream, let recipe, let mode):
                let inputTexture = try upstream.makeTextureUncached(
                    profile: profile,
                    derivative: nil,
                    samplerDescriptor: activeSamplerDescriptor,
                    executionIdentifier: nil
                )
                plan = try makeWrappedEditRenderPlan(
                    source: .texture(inputTexture),
                    recipe: recipe,
                    mode: mode,
                    extraFilters: filters,
                    profile: profile,
                    derivative: derivative,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: try upstream.resolvedPrimarySource().descriptor,
                    optimization: optimization
                )
            case .transition(let recipe):
                let inputSize: C7Size
                if let size = recipe.from.resolvedSizeHint {
                    inputSize = size
                } else {
                    let texture = try recipe.from.makeTexture()
                    inputSize = C7Size(width: texture.width, height: texture.height)
                }
                plan = GraphCompiler.compile(
                    filters: [try recipe.makeFilter()] + filters,
                    inputSize: inputSize,
                    profile: profile,
                    derivative: derivative ?? recipe.derivative,
                    compilationSource: .transition,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: recipe.from.descriptor,
                    auxiliaryInputDescriptor: recipe.to.descriptor,
                    imageGraph: optimization.graph,
                    graphOptimizationDecisions: optimization.decisions
                )
            default:
                let inputSize: C7Size
                if let size = input.resolvedPlanningOutputSizeHint(profile: profile) {
                    inputSize = size
                } else {
                    let texture = try input.makeTexture(profile: profile, derivative: nil)
                    inputSize = C7Size(width: texture.width, height: texture.height)
                }
                plan = GraphCompiler.compile(
                    filters: filters,
                    inputSize: inputSize,
                    profile: profile,
                    derivative: derivative ?? profile.defaultDerivativeSpec,
                    compilationSource: input.compilationSource,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: (try input.resolvedPrimarySource()).descriptor,
                    imageGraph: optimization.graph,
                    graphOptimizationDecisions: optimization.decisions
                )
            }
        case .kernel(let input, let descriptor, let filter):
            switch input.storage {
            case .recipe(let source, let recipe, let mode):
                let sourceTexture = try source.makeTexture()
                try descriptor.validateCompatibility(
                    with: filter,
                    inputSize: C7Size(
                        width: sourceTexture.width,
                        height: sourceTexture.height
                    )
                )
                plan = try makeWrappedEditRenderPlan(
                    source: source,
                    recipe: recipe,
                    mode: mode,
                    extraFilters: [filter],
                    profile: profile,
                    derivative: derivative,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: source.descriptor,
                    optimization: optimization
                )
            case .edit(let upstream, let recipe, let mode):
                let inputTexture = try upstream.makeTextureUncached(
                    profile: profile,
                    derivative: nil,
                    samplerDescriptor: activeSamplerDescriptor,
                    executionIdentifier: nil
                )
                try descriptor.validateCompatibility(
                    with: filter,
                    inputSize: C7Size(width: inputTexture.width, height: inputTexture.height)
                )
                plan = try makeWrappedEditRenderPlan(
                    source: .texture(inputTexture),
                    recipe: recipe,
                    mode: mode,
                    extraFilters: [filter],
                    profile: profile,
                    derivative: derivative,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: try upstream.resolvedPrimarySource().descriptor,
                    optimization: optimization
                )
            default:
                let inputSize: C7Size
                if let size = input.resolvedPlanningOutputSizeHint(profile: profile) {
                    inputSize = size
                } else {
                    let texture = try input.makeTexture(profile: profile, derivative: nil)
                    inputSize = C7Size(width: texture.width, height: texture.height)
                }
                try descriptor.validateCompatibility(
                    with: filter,
                    inputSize: inputSize
                )
                plan = GraphCompiler.compile(
                    filters: [filter],
                    inputSize: inputSize,
                    profile: profile,
                    derivative: derivative ?? profile.defaultDerivativeSpec,
                    compilationSource: input.compilationSource,
                    outputContract: descriptor.outputContract,
                    samplerDescriptor: activeSamplerDescriptor,
                    sourceDescriptor: (try input.resolvedPrimarySource()).descriptor,
                    imageGraph: optimization.graph,
                    graphOptimizationDecisions: optimization.decisions
                )
            }
        case .recipe(let source, let recipe, let mode):
            plan = try makeWrappedEditRenderPlan(
                source: source,
                recipe: recipe,
                mode: mode,
                extraFilters: [],
                profile: profile,
                derivative: derivative,
                samplerDescriptor: activeSamplerDescriptor,
                sourceDescriptor: source.descriptor,
                optimization: optimization
            )
        case .edit(let input, let recipe, let mode):
            let inputTexture = try input.makeTextureUncached(
                profile: profile,
                derivative: nil,
                samplerDescriptor: activeSamplerDescriptor,
                executionIdentifier: nil
            )
            plan = try makeWrappedEditRenderPlan(
                source: .texture(inputTexture),
                recipe: recipe,
                mode: mode,
                extraFilters: [],
                profile: profile,
                derivative: derivative,
                samplerDescriptor: activeSamplerDescriptor,
                sourceDescriptor: try input.resolvedPrimarySource().descriptor,
                optimization: optimization
            )
        case .transition(let recipe):
            let inputSize: C7Size
            if let size = recipe.from.resolvedSizeHint {
                inputSize = size
            } else {
                let texture = try recipe.from.makeTexture()
                inputSize = C7Size(width: texture.width, height: texture.height)
            }
            plan = GraphCompiler.compile(
                filters: [try recipe.makeFilter()],
                inputSize: inputSize,
                profile: profile,
                derivative: derivative ?? recipe.derivative,
                compilationSource: .transition,
                samplerDescriptor: activeSamplerDescriptor,
                sourceDescriptor: recipe.from.descriptor,
                auxiliaryInputDescriptor: recipe.to.descriptor,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            )
        case .layerComposite(let recipe):
            plan = try recipe.makeRenderPlan(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: activeSamplerDescriptor
            )
        case .cachePolicy(let input, let policy):
            let innerPlan = try input.makeRenderPlan(
                profile: profile,
                derivative: derivative,
                samplerDescriptorOverride: activeSamplerDescriptor
            )
            plan = RenderPlan(
                graph: innerPlan.graph,
                profile: innerPlan.profile,
                derivative: innerPlan.diagnostics.derivative,
                inputSize: innerPlan.diagnostics.inputSize,
                outputSize: innerPlan.diagnostics.outputSize,
                nodeDiagnostics: innerPlan.diagnostics.nodes,
                compilationSource: innerPlan.diagnostics.compilationSource,
                outputContract: innerPlan.diagnostics.outputContract,
                imageCachePolicy: policy,
                samplerDescriptor: innerPlan.diagnostics.samplerDescriptor,
                samplerExecutionCoverage: innerPlan.diagnostics.samplerExecutionCoverage,
                sourceDescriptor: try input.resolvedPrimarySource().descriptor,
                inputColorConversionCount: innerPlan.diagnostics.inputColorConversionCount,
                inputPixelFormatConversionCount: innerPlan.diagnostics.inputPixelFormatConversionCount,
                inputAlphaConversionCount: innerPlan.diagnostics.inputAlphaConversionCount,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            )
        case .samplerDescriptor(let input, let descriptor):
            _ = Shared.shared.defaultContext.makeSamplerState(descriptor)
            let innerPlan = try input.makeRenderPlan(
                profile: profile,
                derivative: derivative,
                samplerDescriptorOverride: descriptor
            )
            plan = RenderPlan(
                graph: innerPlan.graph,
                profile: innerPlan.profile,
                derivative: innerPlan.diagnostics.derivative,
                inputSize: innerPlan.diagnostics.inputSize,
                outputSize: innerPlan.diagnostics.outputSize,
                nodeDiagnostics: innerPlan.diagnostics.nodes,
                compilationSource: innerPlan.diagnostics.compilationSource,
                outputContract: innerPlan.diagnostics.outputContract,
                imageCachePolicy: innerPlan.diagnostics.imageCachePolicy,
                samplerDescriptor: descriptor,
                samplerExecutionCoverage: innerPlan.diagnostics.samplerExecutionCoverage,
                sourceDescriptor: try input.resolvedPrimarySource().descriptor,
                inputColorConversionCount: innerPlan.diagnostics.inputColorConversionCount,
                inputPixelFormatConversionCount: innerPlan.diagnostics.inputPixelFormatConversionCount,
                inputAlphaConversionCount: innerPlan.diagnostics.inputAlphaConversionCount,
                imageGraph: optimization.graph,
                graphOptimizationDecisions: optimization.decisions
            )
        }
        Shared.shared.defaultContext.storeRenderPlan(plan, for: cacheKey)
        return plan
    }

    /// Builds the LRU cache key for a `makeRenderPlan` call.
    /// Same `(node, profile, derivative, samplerDescriptor)` → same key.
    static func makeRenderPlanCacheKey(nodeFingerprint: String,
                                       profile: RenderProfile,
                                       derivative: ImageDerivativeSpec,
                                       samplerDescriptor: ImageSamplerDescriptor) -> String {
        "\(nodeFingerprint)|profile=\(profile.rawValue)|derivative=\(derivative.name)|sampler=\(samplerDescriptor.fingerprint)"
    }

    func makeRenderRecipe(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRecipe {
        switch storage {
        case .recipe(let source, let recipe, let mode):
            return try recipe.makeRenderRecipe(
                source: source,
                mode: mode,
                derivative: derivative,
                samplerDescriptor: resolvedSamplerDescriptor
            )
        case .edit(let input, let recipe, let mode):
            let inputTexture = try input.makeTextureUncached(
                profile: profile,
                derivative: nil,
                samplerDescriptor: resolvedSamplerDescriptor,
                executionIdentifier: nil
            )
            let originalSource = try input.resolvedPrimarySource()
            return try recipe.makeRenderRecipe(
                source: .texture(inputTexture),
                mode: mode,
                derivative: derivative,
                samplerDescriptor: resolvedSamplerDescriptor,
                sourceDescriptorOverride: originalSource.descriptor,
                alphaTypeOverride: originalSource.alphaType,
                orientationOverride: originalSource.orientation
            )
        case .layerComposite(let recipe):
            return try recipe.makeRenderRecipe(
                profile: profile,
                derivative: derivative,
                samplerDescriptor: resolvedSamplerDescriptor
            )
        default:
            break
        }
        let plan = try makeRenderPlan(profile: profile, derivative: derivative)
        let primarySource = try resolvedPrimarySource()
        let filters = plan.diagnostics.nodes
            .filter { $0.name != "DerivativeResize" }
            .map { diagnostic in
                FilterRecipeDescriptor(
                    stableTypeID: diagnostic.name,
                    modifier: diagnostic.kind.rawValue,
                    parameterValues: diagnostic.parameterSummary
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key)=\($0.value)" },
                    otherInputTextureCount: 0,
                    pipelineFilterFingerprints: [],
                    finalFilterFingerprint: nil
                )
            }
        return RenderRecipe(
            renderProfile: String(describing: plan.profile),
            renderIntent: plan.diagnostics.derivative.renderIntent,
            source: primarySource.descriptor,
            outputDerivative: plan.diagnostics.derivative,
            outputCachePolicy: resolvedCachePolicy,
            outputSemantic: plan.diagnostics.derivative.semantic,
            alphaType: primarySource.alphaType,
            orientation: primarySource.orientation,
            filters: filters,
            localEffects: nil,
            layerMasks: nil
        )
    }

    private func resizeTextureIfNeeded(_ texture: MTLTexture,
                                       derivative: ImageDerivativeSpec,
                                       profile: RenderProfile,
                                       executionIdentifier: String? = nil) throws -> MTLTexture {
        try ImageNode.applyDerivativeResize(
            texture,
            derivative: derivative,
            profile: profile,
            identifier: executionIdentifier ?? monitoringIdentifier
        )
    }

    /// Resize a texture to match the target size defined by `derivative`.
    /// Returns the input unchanged when sizes already match.
    ///
    /// Single source of truth for derivative-driven resizing, shared between
    /// `ImageNode.makeTextureUncached` and `LayerCompositeRecipe.makeTexture`.
    static func applyDerivativeResize(_ texture: MTLTexture,
                                      derivative: ImageDerivativeSpec,
                                      profile: RenderProfile,
                                      identifier: String? = nil) throws -> MTLTexture {
        let targetSize = derivative.resolvedOutputSize(for: C7Size(width: texture.width, height: texture.height))
        guard targetSize.width != texture.width || targetSize.height != texture.height else {
            return texture
        }
        return try HarbethIO(
            element: texture,
            filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height)),
            identifier: identifier ?? "ImageNode.DerivativeResize"
        )
        .configured(for: profile)
        .output()
    }

    private var monitoringIdentifier: String {
        "ImageNode.\(nodeFingerprint)"
    }

    var resolvedCachePolicy: ImageCachePolicy {
        switch storage {
        case .source(let source):
            return source.cachePolicy
        case .filters(let input, _):
            return input.resolvedCachePolicy
        case .kernel(let input, _, _):
            return input.resolvedCachePolicy
        case .recipe(let source, _, _):
            return source.cachePolicy
        case .edit(let input, _, _):
            return input.resolvedCachePolicy
        case .transition(let recipe):
            return recipe.from.cachePolicy
        case .layerComposite(let recipe):
            return recipe.background.cachePolicy
        case .cachePolicy(_, let policy):
            return policy
        case .samplerDescriptor(let input, _):
            return input.resolvedCachePolicy
        }
    }

    var resolvedSamplerDescriptor: ImageSamplerDescriptor {
        switch storage {
        case .samplerDescriptor(_, let descriptor):
            return descriptor
        case .cachePolicy(let input, _):
            return input.resolvedSamplerDescriptor
        case .source, .filters, .kernel, .recipe, .edit, .transition, .layerComposite:
            return .default
        }
    }

    fileprivate func resolvedFrameColorSpace(for source: ImageSource, outputColorSpace: ImageColorSpaceContract) -> CGColorSpace? {
        if outputColorSpace.preservesInput == false,
           let colorSpace = outputColorSpace.cgColorSpace {
            return colorSpace
        }
        if let colorSpace = source.colorSpace {
            return colorSpace
        }
        let sourceDescriptor = source.descriptor
        if let colorSpace = sourceDescriptor.pixelBufferContract?.attachmentColorSpace?.cgColorSpace {
            return colorSpace
        }
        if let colorSpace = sourceDescriptor.sampleBufferContract?.pixelBufferContract?.attachmentColorSpace?.cgColorSpace {
            return colorSpace
        }
        return nil
    }

    fileprivate func makePreviewHostPayload(source: ImageSource, renderedTexture: MTLTexture, renderRecipe: RenderRecipe) -> RenderedFramePreviewHostPayload? {
        guard case .sampleBuffer(let sampleBuffer) = source else {
            return nil
        }
        let sourceImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let sourceWidth = sourceImageBuffer.map(CVPixelBufferGetWidth)
        let sourceHeight = sourceImageBuffer.map(CVPixelBufferGetHeight)
        let preservesDisplaySemantics = renderRecipe.filters.isEmpty
            && sourceWidth == renderedTexture.width
            && sourceHeight == renderedTexture.height
        if preservesDisplaySemantics {
            return RenderedFramePreviewHostPayload(passthroughSampleBuffer: sampleBuffer)
        }
        return RenderedFramePreviewHostPayload(sampleBufferFactory: {
            try Self.makePreviewHostRematerializedSampleBuffer(
                texture: renderedTexture,
                referenceSampleBuffer: sampleBuffer
            )
        })
    }

    fileprivate func resolvedPreviewHostStrategy(source: ImageSource, renderedTexture: MTLTexture, renderRecipe: RenderRecipe) -> PreviewHostStrategy {
        guard case .sampleBuffer(let sampleBuffer) = source else {
            return .metalTextureHost
        }
        let sourceImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let sourceWidth = sourceImageBuffer.map(CVPixelBufferGetWidth)
        let sourceHeight = sourceImageBuffer.map(CVPixelBufferGetHeight)
        let preservesDisplaySemantics = renderRecipe.filters.isEmpty
            && sourceWidth == renderedTexture.width
            && sourceHeight == renderedTexture.height
        return preservesDisplaySemantics ? .sampleBufferPassthroughHost : .sampleBufferRematerializedHost
    }

    fileprivate static func makePreviewHostRematerializedSampleBuffer(texture: MTLTexture, referenceSampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer? {
        let referencePixelBuffer = CMSampleBufferGetImageBuffer(referenceSampleBuffer)
        let referenceFormatType = referencePixelBuffer.map(CVPixelBufferGetPixelFormatType)
        let resolvedFormatType: OSType
        if let referencePixelBuffer,
           referencePixelBuffer.c7.contract.planar == false,
           let preferredType = RenderPixelBufferDescriptor.pixelFormatType(for: texture.pixelFormat),
           preferredType == referenceFormatType {
            resolvedFormatType = preferredType
        } else if let fallbackType = RenderPixelBufferDescriptor.pixelFormatType(for: texture.pixelFormat) {
            resolvedFormatType = fallbackType
        } else {
            resolvedFormatType = kCVPixelFormatType_32BGRA
        }
        let pool = try PixelBufferPool(
            width: texture.width,
            height: texture.height,
            pixelFormatType: resolvedFormatType,
            minimumBufferCount: 1
        )
        let pixelBuffer = try pool.makePixelBuffer()
        if let compatibilityError = pixelBuffer.c7.textureCopyCompatibilityError(for: texture) {
            throw compatibilityError
        }
        guard pixelBuffer.c7.copyToPixelBuffer(with: texture) else {
            throw HarbethError.pixelBufferCopyFailed
        }
        if let imageBuffer = referencePixelBuffer {
            pixelBuffer.c7.copyAttachments(from: imageBuffer)
        }
        return pixelBuffer.c7.toCMSampleBuffer(reference: referenceSampleBuffer)
    }

    func resolvedPlanningOutputSizeHint(profile: RenderProfile) -> C7Size? {
        switch storage {
        case .source(let source):
            return source.resolvedSizeHint
        case .filters(let input, let filters):
            guard let inputSize = input.resolvedPlanningOutputSizeHint(profile: profile) else {
                return nil
            }
            return filters.reduce(inputSize) { size, filter in
                filter.resize(input: size)
            }
        case .kernel(let input, _, let filter):
            guard let inputSize = input.resolvedPlanningOutputSizeHint(profile: profile) else {
                return nil
            }
            return filter.resize(input: inputSize)
        case .recipe, .edit, .transition, .layerComposite:
            return nil
        case .cachePolicy(let input, _), .samplerDescriptor(let input, _):
            return input.resolvedPlanningOutputSizeHint(profile: profile)
        }
    }

    private var nodeFingerprint: String {
        switch storage {
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
            let planning = recipe.planningDescriptor(for: mode)
            return [
                "recipe",
                source.resolutionFingerprint,
                "mode=\(mode.rawValue)",
                planning.fingerprint
            ].joined(separator: "|")
        case .edit(let input, let recipe, let mode):
            let planning = recipe.planningDescriptor(for: mode)
            return [
                "edit",
                input.nodeFingerprint,
                "mode=\(mode.rawValue)",
                planning.fingerprint
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

    func resolvedPrimarySource() throws -> ImageSource {
        switch storage {
        case .source(let source):
            return source
        case .filters(let input, _), .kernel(let input, _, _), .cachePolicy(let input, _), .samplerDescriptor(let input, _):
            return try input.resolvedPrimarySource()
        case .recipe(let source, _, _):
            return source
        case .edit(let input, _, _):
            return try input.resolvedPrimarySource()
        case .transition(let recipe):
            return recipe.from
        case .layerComposite(let recipe):
            return recipe.background
        }
    }

    private func resolvedAttachmentAnalysisBridge(profile: RenderProfile) throws -> (inputTexture: MTLTexture, filter: any RenderProtocol)? {
        switch storage {
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
        case .samplerDescriptor(let input, let descriptor):
            guard let bridge = try input.resolvedAttachmentAnalysisBridge(profile: profile) else {
                return nil
            }
            let adaptedFilter: any RenderProtocol = SamplerExecutionAdapter.adapt(
                renderFilter: bridge.filter,
                samplerDescriptor: descriptor
            )
            return (bridge.inputTexture, adaptedFilter)
        case .source, .recipe, .edit, .transition, .layerComposite:
            return nil
        }
    }

    private func makeWrappedEditRenderPlan(source: ImageSource,
                                           recipe: EditRecipe,
                                           mode: EditRecipeMode,
                                           extraFilters: [C7FilterProtocol],
                                           profile: RenderProfile,
                                           derivative: ImageDerivativeSpec?,
                                           samplerDescriptor: ImageSamplerDescriptor,
                                           sourceDescriptor: ImageSourceDescriptor,
                                           optimization: ImageGraphOptimizationResult) throws -> RenderPlan {
        let plan = try recipe.makeRenderPlan(
            source: source,
            mode: mode,
            extraFilters: extraFilters,
            derivative: derivative,
            samplerDescriptor: samplerDescriptor
        )
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
            samplerDescriptor: plan.diagnostics.samplerDescriptor,
            samplerExecutionCoverage: plan.diagnostics.samplerExecutionCoverage,
            sourceDescriptor: sourceDescriptor,
            inputColorConversionCount: plan.diagnostics.inputColorConversionCount,
            inputPixelFormatConversionCount: plan.diagnostics.inputPixelFormatConversionCount,
            inputAlphaConversionCount: plan.diagnostics.inputAlphaConversionCount,
            imageGraph: optimization.graph,
            graphOptimizationDecisions: optimization.decisions
        )
    }
}

extension ImageNode {
    private static let outputContractResultCache: NSCache<NSString, BoxedTexture> = {
        let cache = NSCache<NSString, BoxedTexture>()
        cache.countLimit = 32
        return cache
    }()

    static func removeAllOutputContractCachedTextures() {
        outputContractResultCache.removeAllObjects()
    }

    static func applyOutputContractIfNeeded(_ contract: RenderOutputContract,
                                            to texture: MTLTexture,
                                            sourceColorSpace: ImageColorSpaceContract = .preserveInput,
                                            sourceAlphaType: AlphaType? = nil,
                                            profile: RenderProfile,
                                            identifier: String? = nil) throws -> MTLTexture {
        let cacheKey = makeOutputContractCacheKey(
            contract: contract,
            inputTexture: texture,
            sourceColorSpace: sourceColorSpace,
            sourceAlphaType: sourceAlphaType,
            profile: profile
        )
        if cacheKey.isEffective,
           let cached = outputContractResultCache.object(forKey: cacheKey.key as NSString) {
            return cached.texture
        }

        var output = texture
        let colorFilters = contract.colorSpace.makeColorConversionFilters(from: sourceColorSpace)
        if colorFilters.isEmpty == false {
            output = try HarbethIO(element: output, filters: colorFilters, identifier: identifier ?? "ImageNode.OutputContract")
                .configured(for: profile)
                .output()
        }
        let filters: [C7FilterProtocol]
        switch contract.alpha {
        case .premultiplied, .forcePremultiply:
            filters = sourceAlphaType == .premultiplied ? [] : [C7PremultiplyAlpha()]
        case .nonPremultiplied, .forceUnpremultiply:
            filters = sourceAlphaType == .nonPremultiplied ? [] : [C7UnpremultiplyAlpha()]
        case .opaque:
            filters = sourceAlphaType == .alphaIsOne ? [] : [C7ForceOpaqueAlpha()]
        case .preserveInput:
            filters = []
        }
        if filters.isEmpty == false {
            output = try HarbethIO(element: output, filters: filters, identifier: identifier ?? "ImageNode.OutputContract")
                .configured(for: profile)
                .output()
        }
        if let targetPixelFormat = contract.pixelFormat.metalPixelFormat, output.pixelFormat != targetPixelFormat {
            var io = HarbethIO(element: output, filter: C7PixelFormatChange(), identifier: identifier ?? "ImageNode.OutputContract")
                .configured(for: profile)
            io.bufferPixelFormat = targetPixelFormat
            io.createDestTexture = true
            output = try io.output()
        }
        let didProduceNewTexture = output !== texture
        if cacheKey.isEffective, didProduceNewTexture {
            outputContractResultCache.setObject(
                BoxedTexture(texture: output),
                forKey: cacheKey.key as NSString
            )
        }
        return output
    }

    /// 输出 contract 缓存键。
    /// 组成:`contract.fingerprint` + `inputTexture` 的
    /// `ObjectIdentifier + width × height × pixelFormat`。
    /// `ObjectIdentifier` 让 cache 在纹理被释放后自动失配(下次 miss 重建),
    /// 不会跨 texture 误命中。
    private static func makeOutputContractCacheKey(contract: RenderOutputContract,
                                                   inputTexture: MTLTexture,
                                                   sourceColorSpace: ImageColorSpaceContract,
                                                   sourceAlphaType: AlphaType?,
                                                   profile: RenderProfile) -> (key: String, isEffective: Bool) {
        let inputFingerprint = "tex|\(ObjectIdentifier(inputTexture).hashValue)|\(inputTexture.width)x\(inputTexture.height)|\(inputTexture.pixelFormat.rawValue)"
        let key = [
            "contract=\(contract.fingerprint)",
            "srcColorSpace=\(sourceColorSpace.fingerprint)",
            "srcAlpha=\(sourceAlphaType.map(String.init(describing:)) ?? "nil")",
            "profile=\(profile.rawValue)",
            inputFingerprint
        ].joined(separator: "||")
        let needsColor = !contract.colorSpace.makeColorConversionFilters(from: sourceColorSpace).isEmpty
        let needsAlpha: Bool
        switch contract.alpha {
        case .premultiplied, .forcePremultiply:
            needsAlpha = sourceAlphaType != .premultiplied
        case .nonPremultiplied, .forceUnpremultiply:
            needsAlpha = sourceAlphaType != .nonPremultiplied
        case .opaque:
            needsAlpha = sourceAlphaType != .alphaIsOne
        case .preserveInput:
            needsAlpha = false
        }
        let needsPixelFormat: Bool
        if let targetPixelFormat = contract.pixelFormat.metalPixelFormat {
            needsPixelFormat = inputTexture.pixelFormat != targetPixelFormat
        } else {
            needsPixelFormat = false
        }
        let isEffective = needsColor || needsAlpha || needsPixelFormat
        return (key, isEffective)
    }
}

//
//  HarbethIO+Frame.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import MetalKit

extension HarbethIO {
    public func configured(for profile: RenderProfile) -> Self {
        var copy = self
        copy.renderProfile = profile
        copy.transmitOutputRealTimeCommit = profile.usesRealTimeCommit
        copy.enableDoubleBuffer = profile.enablesDoubleBuffer
        copy.createDestTexture = profile.createsDestinationTexture
        return copy
    }

    /// texture-first 同步输出，不执行 CPU 读回。
    public func renderTexture(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        let sourceObject = try makeImageSource()
        let source = try sourceObject.makeTexture()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let effectiveFilters = makeEffectiveFilters(
            inputSize: C7Size(width: source.width, height: source.height),
            derivative: effectiveDerivative
        )
        guard effectiveFilters.isEmpty == false else { return source }
        return try HarbethIO<MTLTexture>(element: source, filters: effectiveFilters)
            .configured(for: profile)
            .output()
    }

    /// 将单帧渲染结果输出为新的 `CVPixelBuffer`，不修改输入 pixel buffer。
    public func renderPixelBuffer(profile: RenderProfile = .stablePreview,
                                  derivative: ImageDerivativeSpec? = nil,
                                  pool: PixelBufferPool? = nil,
                                  pixelFormatType: OSType = kCVPixelFormatType_32BGRA,
                                  outputPixelFormat: PixelFormatContract = .preserveInput) throws -> CVPixelBuffer {
        let texture = try renderTextureForPixelBuffer(
            profile: profile,
            derivative: derivative,
            requestedPixelFormatType: pixelFormatType,
            outputPixelFormat: outputPixelFormat
        )
        let resolvedPixelFormatType = try resolvePixelBufferFormatType(
            requestedPixelFormatType: pixelFormatType,
            outputPixelFormat: outputPixelFormat,
            renderedTexture: texture
        )
        let outputPool = try pool ?? PixelBufferPool(
            width: texture.width,
            height: texture.height,
            pixelFormatType: resolvedPixelFormatType
        )
        let pixelBuffer = try outputPool.makePixelBuffer()
        if let compatibilityError = pixelBuffer.c7.textureCopyCompatibilityError(for: texture) {
            throw compatibilityError
        }
        guard pixelBuffer.c7.copyToPixelBuffer(with: texture) else {
            throw HarbethError.pixelBufferCopyFailed
        }
        copySourceImageBufferAttachmentsIfNeeded(to: pixelBuffer)
        return pixelBuffer
    }

    private func renderTextureForPixelBuffer(profile: RenderProfile,
                                             derivative: ImageDerivativeSpec?,
                                             requestedPixelFormatType: OSType,
                                             outputPixelFormat: PixelFormatContract) throws -> MTLTexture {
        let sourceObject = try makeImageSource()
        let source = try sourceObject.makeTexture()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        var effectiveFilters = makeEffectiveFilters(
            inputSize: C7Size(width: source.width, height: source.height),
            derivative: effectiveDerivative
        )
        let targetPixelFormat: MTLPixelFormat? = {
            if outputPixelFormat.preservesInput {
                return Self.preferredMetalPixelFormat(for: requestedPixelFormatType)
            }
            return outputPixelFormat.metalPixelFormat
        }()
        if effectiveFilters.isEmpty,
           let targetPixelFormat,
           source.pixelFormat != targetPixelFormat {
            effectiveFilters = [C7Brightness(brightness: 0)]
        }
        guard effectiveFilters.isEmpty == false else {
            return source
        }
        var io = HarbethIO<MTLTexture>(element: source, filters: effectiveFilters)
            .configured(for: profile)
        if let targetPixelFormat {
            io.bufferPixelFormat = targetPixelFormat
            io.createDestTexture = true
        }
        return try io.output()
    }

    private static func preferredMetalPixelFormat(for pixelFormatType: OSType) -> MTLPixelFormat? {
        switch pixelFormatType {
        case kCVPixelFormatType_32BGRA:
            return .bgra8Unorm
        case kCVPixelFormatType_32RGBA, kCVPixelFormatType_32ARGB:
            return .rgba8Unorm
        case kCVPixelFormatType_64RGBAHalf:
            return .rgba16Float
        case kCVPixelFormatType_OneComponent8:
            return .r8Unorm
        default:
            return nil
        }
    }

    private func resolvePixelBufferFormatType(requestedPixelFormatType: OSType,
                                              outputPixelFormat: PixelFormatContract,
                                              renderedTexture: MTLTexture) throws -> OSType {
        if outputPixelFormat.preservesInput {
            return requestedPixelFormatType
        }
        guard let targetPixelFormat = outputPixelFormat.metalPixelFormat else {
            throw HarbethError.configurationInvalid("Pixel buffer output pixel format contract must resolve to a Metal pixel format.")
        }
        guard let resolvedType = RenderPixelBufferDescriptor.pixelFormatType(for: targetPixelFormat) else {
            throw HarbethError.configurationInvalid(
                "Pixel buffer output does not support Metal pixel format \(targetPixelFormat)."
            )
        }
        if renderedTexture.pixelFormat != targetPixelFormat {
            throw HarbethError.configurationInvalid(
                "Rendered texture pixel format mismatch for pixel buffer output. Texture pixelFormat=\(renderedTexture.pixelFormat), expected \(targetPixelFormat)."
            )
        }
        return resolvedType
    }

    private func copySourceImageBufferAttachmentsIfNeeded(to pixelBuffer: CVPixelBuffer) {
        switch element {
        case let source where CFGetTypeID(source as CFTypeRef) == CVPixelBufferGetTypeID():
            pixelBuffer.c7.copyAttachments(from: source as! CVPixelBuffer)
        case let source where CFGetTypeID(source as CFTypeRef) == CMSampleBufferGetTypeID():
            guard let imageBuffer = CMSampleBufferGetImageBuffer(source as! CMSampleBuffer) else {
                return
            }
            pixelBuffer.c7.copyAttachments(from: imageBuffer)
        default:
            break
        }
    }

    /// texture-first task output for callers that need to observe GPU completion.
    public func startRenderTextureTask(profile: RenderProfile = .stablePreview,
                                       derivative: ImageDerivativeSpec? = nil) throws -> RenderTask<MTLTexture> {
        let sourceObject = try makeImageSource()
        let source = try sourceObject.makeTexture()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let effectiveFilters = makeEffectiveFilters(
            inputSize: C7Size(width: source.width, height: source.height),
            derivative: effectiveDerivative
        )
        let diagnostics = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: source.width, height: source.height),
            profile: profile,
            derivative: effectiveDerivative,
            compilationSource: .filtersPrimitive,
            sourceDescriptor: sourceObject.descriptor
        ).diagnostics
        guard effectiveFilters.isEmpty == false else {
            return .completed(identifier: identifier, output: source, diagnostics: diagnostics)
        }
        return try HarbethIO<MTLTexture>(element: source, filters: effectiveFilters)
            .configured(for: profile)
            .startRenderTextureTask(diagnostics: diagnostics)
    }

    /// 结构化渲染计划诊断，供上层做日志、调度、缓存和大图策略分析。
    public func renderDiagnostics(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        let sourceObject = try makeImageSource()
        let source = try sourceObject.makeTexture()
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: source.width, height: source.height),
            profile: profile,
            derivative: derivative ?? profile.defaultDerivativeSpec,
            compilationSource: .filtersPrimitive,
            sourceDescriptor: sourceObject.descriptor
        )
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.recordRenderStageCount(identifier, stageCount: plan.optimizedStages.count)
            if plan.requiresCompletedGPUWork {
                Shared.shared.performanceMonitor?.recordReadbackBoundary(identifier)
            }
        }
        return plan.diagnostics
    }

    public func renderDiagnosticsJSONData(profile: RenderProfile = .stablePreview,
                                          derivative: ImageDerivativeSpec? = nil,
                                          prettyPrinted: Bool = false,
                                          sortedKeys: Bool = true) throws -> Data {
        try renderDiagnostics(profile: profile, derivative: derivative)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderDiagnosticsJSONString(profile: RenderProfile = .stablePreview,
                                            derivative: ImageDerivativeSpec? = nil,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> String {
        try renderDiagnostics(profile: profile, derivative: derivative)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderRecipe(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRecipe {
        let source = try makeImageSource()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let outputCachePolicy: ImageCachePolicy = filters.isEmpty ? source.cachePolicy : .transient
        return RenderRecipe(
            renderProfile: String(describing: profile),
            renderIntent: effectiveDerivative.renderIntent,
            source: source.descriptor,
            outputDerivative: effectiveDerivative,
            outputCachePolicy: outputCachePolicy,
            outputSemantic: effectiveDerivative.semantic,
            alphaType: source.alphaType,
            orientation: source.orientation,
            filters: filters.map(\.recipeDescriptor)
        )
    }

    public func makeRenderRequest(profile: RenderProfile = .stablePreview,
                                  derivative: ImageDerivativeSpec? = nil) throws -> RenderRequest {
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let renderRecipe = try renderRecipe(profile: profile, derivative: effectiveDerivative)
        let diagnostics = try renderDiagnostics(profile: profile, derivative: effectiveDerivative)
        let source = try makeImageSource()
        return RenderRequest(
            compilationSource: .filtersPrimitive,
            profile: profile,
            derivative: effectiveDerivative,
            source: source.descriptor,
            outputCachePolicy: renderRecipe.outputCachePolicy,
            diagnostics: diagnostics,
            renderRecipe: renderRecipe,
            renderTexture: { try renderTexture(profile: profile, derivative: effectiveDerivative) },
            renderFrame: { metadata in
                try renderFrame(profile: profile, derivative: effectiveDerivative, metadata: metadata)
            }
        )
    }

    public func renderTexture(recipe: EditRecipe,
                              mode: EditRecipeMode = .preview,
                              derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        let source = try makeImageSource()
        return try FrameRenderer(
            source: source,
            recipe: recipe,
            mode: mode,
            filters: filters,
            identifier: identifier,
            derivative: derivative
        ).renderTexture()
    }

    public func renderTexture(node: ImageNode,
                              profile: RenderProfile = .stablePreview,
                              derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        try node.makeTexture(profile: profile, derivative: derivative)
    }

    public func renderDiagnostics(recipe: EditRecipe,
                                  mode: EditRecipeMode = .preview,
                                  derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        let plan = try recipe.makeRenderPlan(
            source: makeImageSource(),
            mode: mode,
            extraFilters: filters,
            derivative: derivative
        )
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.recordRenderStageCount(identifier, stageCount: plan.optimizedStages.count)
            if plan.requiresCompletedGPUWork {
                Shared.shared.performanceMonitor?.recordReadbackBoundary(identifier)
            }
        }
        return plan.diagnostics
    }

    public func renderDiagnosticsJSONData(recipe: EditRecipe,
                                          mode: EditRecipeMode = .preview,
                                          derivative: ImageDerivativeSpec? = nil,
                                          prettyPrinted: Bool = false,
                                          sortedKeys: Bool = true) throws -> Data {
        try renderDiagnostics(recipe: recipe, mode: mode, derivative: derivative)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderDiagnosticsJSONString(recipe: EditRecipe,
                                            mode: EditRecipeMode = .preview,
                                            derivative: ImageDerivativeSpec? = nil,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> String {
        try renderDiagnostics(recipe: recipe, mode: mode, derivative: derivative)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderTexture(composite recipe: LayerCompositeRecipe,
                              derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        try recipe.makeTexture(derivative: derivative)
    }

    public func makeRenderRequest(recipe: EditRecipe,
                                  mode: EditRecipeMode = .preview,
                                  derivative: ImageDerivativeSpec? = nil) throws -> RenderRequest {
        try recipe.makeRenderRequest(
            source: makeImageSource(),
            mode: mode,
            extraFilters: filters,
            derivative: derivative,
            identifier: identifier
        )
    }

    public func renderDiagnostics(composite recipe: LayerCompositeRecipe,
                                  derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        let diagnostics = try recipe.makeDiagnostics(derivative: derivative)
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.recordRenderStageCount(identifier, stageCount: diagnostics.stageCount)
            if diagnostics.requiresCompletedGPUWork {
                Shared.shared.performanceMonitor?.recordReadbackBoundary(identifier)
            }
        }
        return diagnostics
    }

    public func renderDiagnosticsJSONData(composite recipe: LayerCompositeRecipe,
                                          derivative: ImageDerivativeSpec? = nil,
                                          prettyPrinted: Bool = false,
                                          sortedKeys: Bool = true) throws -> Data {
        try renderDiagnostics(composite: recipe, derivative: derivative)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderDiagnosticsJSONString(composite recipe: LayerCompositeRecipe,
                                            derivative: ImageDerivativeSpec? = nil,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> String {
        try renderDiagnostics(composite: recipe, derivative: derivative)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderFrame(composite recipe: LayerCompositeRecipe,
                            derivative: ImageDerivativeSpec? = nil,
                            metadata: [String: String] = [:]) throws -> RenderedFrame {
        try recipe.makeNode().makeFrame(
            profile: recipe.profile,
            derivative: derivative ?? recipe.derivative,
            metadata: metadata
        )
    }

    public func makeRenderRequest(composite recipe: LayerCompositeRecipe,
                                  derivative: ImageDerivativeSpec? = nil) throws -> RenderRequest {
        try recipe.makeRenderRequest(derivative: derivative)
    }

    public func renderDiagnostics(node: ImageNode,
                                  profile: RenderProfile = .stablePreview,
                                  derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        let diagnostics = try node.makeDiagnostics(profile: profile, derivative: derivative)
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.recordRenderStageCount(identifier, stageCount: diagnostics.stageCount)
            if diagnostics.requiresCompletedGPUWork {
                Shared.shared.performanceMonitor?.recordReadbackBoundary(identifier)
            }
        }
        return diagnostics
    }

    public func renderDiagnosticsJSONData(node: ImageNode,
                                          profile: RenderProfile = .stablePreview,
                                          derivative: ImageDerivativeSpec? = nil,
                                          prettyPrinted: Bool = false,
                                          sortedKeys: Bool = true) throws -> Data {
        try renderDiagnostics(node: node, profile: profile, derivative: derivative)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderDiagnosticsJSONString(node: ImageNode,
                                            profile: RenderProfile = .stablePreview,
                                            derivative: ImageDerivativeSpec? = nil,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> String {
        try renderDiagnostics(node: node, profile: profile, derivative: derivative)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderDebugSnapshot(node: ImageNode,
                                    profile: RenderProfile = .stablePreview,
                                    derivative: ImageDerivativeSpec? = nil) throws -> RenderGraphDebugSnapshot {
        try node.makeDebugSnapshot(profile: profile, derivative: derivative)
    }

    public func renderDebugSnapshotJSONData(node: ImageNode,
                                            profile: RenderProfile = .stablePreview,
                                            derivative: ImageDerivativeSpec? = nil,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> Data {
        try node.makeDebugSnapshotJSONData(
            profile: profile,
            derivative: derivative,
            prettyPrinted: prettyPrinted,
            sortedKeys: sortedKeys
        )
    }

    public func renderDebugSnapshotJSONString(node: ImageNode,
                                              profile: RenderProfile = .stablePreview,
                                              derivative: ImageDerivativeSpec? = nil,
                                              prettyPrinted: Bool = false,
                                              sortedKeys: Bool = true) throws -> String {
        try node.makeDebugSnapshotJSONString(
            profile: profile,
            derivative: derivative,
            prettyPrinted: prettyPrinted,
            sortedKeys: sortedKeys
        )
    }

    public func renderAttachmentDebugPolicies(node: ImageNode,
                                              profile: RenderProfile = .stablePreview,
                                              derivative: ImageDerivativeSpec? = nil) throws -> [RenderOutputAttachmentDebugPolicy] {
        try node.makeAttachmentDebugPolicies(profile: profile, derivative: derivative)
    }

    public func renderDebugSnapshot(recipe: EditRecipe,
                                    mode: EditRecipeMode = .preview,
                                    derivative: ImageDerivativeSpec? = nil) throws -> RenderGraphDebugSnapshot {
        let source = try makeImageSource()
        return try ImageNode.recipe(source: source, recipe: recipe, mode: mode)
            .makeDebugSnapshot(profile: recipe.contract(for: mode).profile, derivative: derivative)
    }

    public func renderDebugSnapshotJSONData(recipe: EditRecipe,
                                            mode: EditRecipeMode = .preview,
                                            derivative: ImageDerivativeSpec? = nil,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> Data {
        try renderDebugSnapshot(recipe: recipe, mode: mode, derivative: derivative)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderDebugSnapshotJSONString(recipe: EditRecipe,
                                              mode: EditRecipeMode = .preview,
                                              derivative: ImageDerivativeSpec? = nil,
                                              prettyPrinted: Bool = false,
                                              sortedKeys: Bool = true) throws -> String {
        try renderDebugSnapshot(recipe: recipe, mode: mode, derivative: derivative)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderAttachmentDebugPolicies(recipe: EditRecipe,
                                              mode: EditRecipeMode = .preview,
                                              derivative: ImageDerivativeSpec? = nil) throws -> [RenderOutputAttachmentDebugPolicy] {
        let source = try makeImageSource()
        return try ImageNode.recipe(source: source, recipe: recipe, mode: mode)
            .makeAttachmentDebugPolicies(profile: recipe.contract(for: mode).profile, derivative: derivative)
    }

    public func renderDebugSnapshot(composite recipe: LayerCompositeRecipe,
                                    derivative: ImageDerivativeSpec? = nil) throws -> RenderGraphDebugSnapshot {
        try recipe.makeNode().makeDebugSnapshot(profile: recipe.profile, derivative: derivative ?? recipe.derivative)
    }

    public func renderDebugSnapshotJSONData(composite recipe: LayerCompositeRecipe,
                                            derivative: ImageDerivativeSpec? = nil,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> Data {
        try renderDebugSnapshot(composite: recipe, derivative: derivative)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderDebugSnapshotJSONString(composite recipe: LayerCompositeRecipe,
                                              derivative: ImageDerivativeSpec? = nil,
                                              prettyPrinted: Bool = false,
                                              sortedKeys: Bool = true) throws -> String {
        try renderDebugSnapshot(composite: recipe, derivative: derivative)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderAttachmentDebugPolicies(composite recipe: LayerCompositeRecipe,
                                              derivative: ImageDerivativeSpec? = nil) throws -> [RenderOutputAttachmentDebugPolicy] {
        try recipe.makeNode().makeAttachmentDebugPolicies(profile: recipe.profile, derivative: derivative ?? recipe.derivative)
    }

    public func renderDebugSnapshot(transition recipe: TransitionRecipe) throws -> RenderGraphDebugSnapshot {
        try ImageNode.transition(recipe).makeDebugSnapshot(profile: recipe.profile, derivative: recipe.derivative)
    }

    public func renderDebugSnapshotJSONData(transition recipe: TransitionRecipe,
                                            prettyPrinted: Bool = false,
                                            sortedKeys: Bool = true) throws -> Data {
        try renderDebugSnapshot(transition: recipe)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderDebugSnapshotJSONString(transition recipe: TransitionRecipe,
                                              prettyPrinted: Bool = false,
                                              sortedKeys: Bool = true) throws -> String {
        try renderDebugSnapshot(transition: recipe)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderAttachmentDebugPolicies(transition recipe: TransitionRecipe) throws -> [RenderOutputAttachmentDebugPolicy] {
        try ImageNode.transition(recipe).makeAttachmentDebugPolicies(profile: recipe.profile, derivative: recipe.derivative)
    }

    /// 直接渲染 filters 路径最终结果并输出 histogram。
    ///
    /// 这个入口保持 Harbeth 的轻量使用方式：
    /// 上层不需要先手动拿 frame/texture 再做一次 histogram 读回。
    public func renderHistogram(profile: RenderProfile = .readbackQuality,
                                derivative: ImageDerivativeSpec? = nil,
                                channel: TextureHistogramChannel = .luminance,
                                bins: Int = 256,
                                preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderFrame(profile: profile, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
    }

    public func renderHistogram(recipe: EditRecipe,
                                mode: EditRecipeMode = .preview,
                                derivative: ImageDerivativeSpec? = nil,
                                channel: TextureHistogramChannel = .luminance,
                                bins: Int = 256,
                                preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderFrame(recipe: recipe, mode: mode, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
    }

    public func renderHistogram(composite recipe: LayerCompositeRecipe,
                                derivative: ImageDerivativeSpec? = nil,
                                channel: TextureHistogramChannel = .luminance,
                                bins: Int = 256,
                                preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderFrame(composite: recipe, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
    }

    public func renderHistogram(node: ImageNode,
                                profile: RenderProfile = .readbackQuality,
                                derivative: ImageDerivativeSpec? = nil,
                                channel: TextureHistogramChannel = .luminance,
                                bins: Int = 256,
                                preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderFrame(node: node, profile: profile, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
    }

    public func renderTransitionHistogram(_ recipe: TransitionRecipe,
                                          channel: TextureHistogramChannel = .luminance,
                                          bins: Int = 256,
                                          preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderTransitionFrame(recipe).makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
    }

    public func renderHistogramAttachment(profile: RenderProfile = .readbackQuality,
                                          derivative: ImageDerivativeSpec? = nil,
                                          channel: TextureHistogramChannel = .luminance,
                                          bins: Int = 256,
                                          height: Int = 64,
                                          preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedHistogramAttachment? {
        try renderFrame(profile: profile, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            preferredMethod: preferredMethod
        )
    }

    public func renderAnalysisBundle(profile: RenderProfile = .readbackQuality,
                                     derivative: ImageDerivativeSpec? = nil,
                                     channel: TextureHistogramChannel = .luminance,
                                     bins: Int = 256,
                                     histogramHeight: Int = 64,
                                     preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle {
        let frame = try renderFrame(profile: profile, derivative: derivative)
        let histogramAttachment = frame.renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: histogramHeight,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
        return RenderedAnalysisBundle(
            frame: frame,
            histogram: histogram,
            histogramAttachment: histogramAttachment,
            attachmentDebugPolicies: [RenderOutputAttachmentContract(index: 0).debugPolicy]
        )
    }

    public func renderHistogramAttachment(recipe: EditRecipe,
                                          mode: EditRecipeMode = .preview,
                                          derivative: ImageDerivativeSpec? = nil,
                                          channel: TextureHistogramChannel = .luminance,
                                          bins: Int = 256,
                                          height: Int = 64,
                                          preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedHistogramAttachment? {
        try renderFrame(recipe: recipe, mode: mode, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            preferredMethod: preferredMethod
        )
    }

    public func renderHistogramAttachment(composite recipe: LayerCompositeRecipe,
                                          derivative: ImageDerivativeSpec? = nil,
                                          channel: TextureHistogramChannel = .luminance,
                                          bins: Int = 256,
                                          height: Int = 64,
                                          preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedHistogramAttachment? {
        try renderFrame(composite: recipe, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            preferredMethod: preferredMethod
        )
    }

    public func renderAnalysisBundle(recipe: EditRecipe,
                                     mode: EditRecipeMode = .preview,
                                     derivative: ImageDerivativeSpec? = nil,
                                     channel: TextureHistogramChannel = .luminance,
                                     bins: Int = 256,
                                     histogramHeight: Int = 64,
                                     preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle {
        let frame = try renderFrame(recipe: recipe, mode: mode, derivative: derivative)
        let histogramAttachment = frame.renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: histogramHeight,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
        return RenderedAnalysisBundle(
            frame: frame,
            histogram: histogram,
            histogramAttachment: histogramAttachment,
            attachmentDebugPolicies: try renderAttachmentDebugPolicies(
                recipe: recipe,
                mode: mode,
                derivative: derivative
            )
        )
    }

    public func renderAnalysisBundle(composite recipe: LayerCompositeRecipe,
                                     derivative: ImageDerivativeSpec? = nil,
                                     channel: TextureHistogramChannel = .luminance,
                                     bins: Int = 256,
                                     histogramHeight: Int = 64,
                                     preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle {
        let frame = try renderFrame(composite: recipe, derivative: derivative)
        let histogramAttachment = frame.renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: histogramHeight,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
        return RenderedAnalysisBundle(
            frame: frame,
            histogram: histogram,
            histogramAttachment: histogramAttachment,
            attachmentDebugPolicies: try renderAttachmentDebugPolicies(composite: recipe, derivative: derivative)
        )
    }

    public func renderHistogramAttachment(node: ImageNode,
                                          profile: RenderProfile = .readbackQuality,
                                          derivative: ImageDerivativeSpec? = nil,
                                          channel: TextureHistogramChannel = .luminance,
                                          bins: Int = 256,
                                          height: Int = 64,
                                          preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedHistogramAttachment? {
        try renderFrame(node: node, profile: profile, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            preferredMethod: preferredMethod
        )
    }

    public func renderAnalysisBundle(node: ImageNode,
                                     profile: RenderProfile = .readbackQuality,
                                     derivative: ImageDerivativeSpec? = nil,
                                     channel: TextureHistogramChannel = .luminance,
                                     bins: Int = 256,
                                     histogramHeight: Int = 64,
                                     preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle {
        let frame = try renderFrame(node: node, profile: profile, derivative: derivative)
        let histogramAttachment = frame.renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: histogramHeight,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
        return RenderedAnalysisBundle(
            frame: frame,
            histogram: histogram,
            histogramAttachment: histogramAttachment,
            attachmentDebugPolicies: try renderAttachmentDebugPolicies(
                node: node,
                profile: profile,
                derivative: derivative
            )
        )
    }

    public func renderTransitionHistogramAttachment(_ recipe: TransitionRecipe,
                                                    channel: TextureHistogramChannel = .luminance,
                                                    bins: Int = 256,
                                                    height: Int = 64,
                                                    preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedHistogramAttachment? {
        try renderTransitionFrame(recipe).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            preferredMethod: preferredMethod
        )
    }

    public func renderTransitionAnalysisBundle(_ recipe: TransitionRecipe,
                                               channel: TextureHistogramChannel = .luminance,
                                               bins: Int = 256,
                                               histogramHeight: Int = 64,
                                               preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle {
        let frame = try renderTransitionFrame(recipe)
        let histogramAttachment = frame.renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: histogramHeight,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
            channel: channel,
            bins: bins,
            preferredMethod: preferredMethod
        )
        return RenderedAnalysisBundle(
            frame: frame,
            histogram: histogram,
            histogramAttachment: histogramAttachment,
            attachmentDebugPolicies: try renderAttachmentDebugPolicies(transition: recipe)
        )
    }

    /// 当 filter 链最后一个节点是真正的 render primitive 时，
    /// 直接返回多 attachment 的轻量分析输出集合。
    ///
    /// 这个入口不会把普通 filter 链强行提升成 MRT runtime；
    /// 只有末端是 `RenderProtocol` 时才返回 bundle。
    public func renderAttachmentAnalysisBundle(profile: RenderProfile = .readbackQuality,
                                               bins: Int = 256,
                                               histogramHeight: Int = 64,
                                               preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle? {
        guard let finalFilter = filters.last as? any RenderProtocol else {
            return nil
        }
        let source = try makeImageSource()
        let inputTexture: MTLTexture
        if filters.count > 1 {
            let preFilters = Array(filters.dropLast())
            inputTexture = try HarbethIO<MTLTexture>(
                element: try source.makeTexture(),
                filters: preFilters
            )
            .configured(for: profile)
            .output()
        } else {
            inputTexture = try source.makeTexture()
        }
        return try finalFilter.renderAttachmentAnalysisBundle(
            from: inputTexture,
            identifier: "\(identifier).attachmentAnalysis",
            bins: bins,
            histogramHeight: histogramHeight,
            preferredMethod: preferredMethod
        )
    }

    /// texture-first 同步帧输出，携带稳定元数据。
    public func renderFrame(profile: RenderProfile = .stablePreview,
                            derivative: ImageDerivativeSpec? = nil,
                            metadata: [String: String] = [:]) throws -> RenderedFrame {
        let source = try makeImageSource()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let renderer = FrameRenderer(
            source: source,
            filters: filters,
            profile: profile,
            renderIntent: effectiveDerivative.renderIntent,
            identifier: identifier,
            metadata: metadata,
            outputSemantic: effectiveDerivative.semantic,
            outputDerivative: effectiveDerivative
        )
        return try renderer.renderFrame()
    }

    public func renderFrame(recipe: EditRecipe,
                            mode: EditRecipeMode = .preview,
                            derivative: ImageDerivativeSpec? = nil,
                            metadata: [String: String] = [:]) throws -> RenderedFrame {
        let source = try makeImageSource()
        return try FrameRenderer(
            source: source,
            recipe: recipe,
            mode: mode,
            filters: filters,
            identifier: identifier,
            metadata: metadata,
            derivative: derivative
        ).renderFrame()
    }

    public func renderFrame(node: ImageNode,
                            profile: RenderProfile = .stablePreview,
                            derivative: ImageDerivativeSpec? = nil,
                            metadata: [String: String] = [:]) throws -> RenderedFrame {
        try node.makeFrame(profile: profile, derivative: derivative, metadata: metadata)
    }

    public func makeFrameRenderToken() -> FrameRenderToken {
        FrameRenderToken(identifier: identifier, generation: FrameGeneration.next())
    }

    public func renderFrame(profile: RenderProfile = .stablePreview,
                            derivative: ImageDerivativeSpec? = nil,
                            token: FrameRenderToken,
                            metadata: [String: String] = [:]) throws -> RenderedFrame {
        let source = try makeImageSource()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        return try FrameRenderer(
            source: source,
            filters: filters,
            profile: profile,
            renderIntent: effectiveDerivative.renderIntent,
            identifier: identifier,
            metadata: metadata,
            outputSemantic: effectiveDerivative.semantic,
            outputDerivative: effectiveDerivative
        ).renderFrame(token: token)
    }

    public func renderFrame(recipe: EditRecipe,
                            mode: EditRecipeMode = .preview,
                            derivative: ImageDerivativeSpec? = nil,
                            token: FrameRenderToken,
                            metadata: [String: String] = [:]) throws -> RenderedFrame {
        let source = try makeImageSource()
        return try FrameRenderer(
            source: source,
            recipe: recipe,
            mode: mode,
            filters: filters,
            identifier: identifier,
            metadata: metadata,
            derivative: derivative
        ).renderFrame(token: token)
    }

    public func renderTransitionTexture(_ recipe: TransitionRecipe) throws -> MTLTexture {
        try FrameRenderer(
            transitionRecipe: recipe,
            filters: filters,
            identifier: identifier
        ).renderTexture()
    }

    public func renderTransitionDiagnostics(_ recipe: TransitionRecipe) throws -> RenderPlanDiagnostics {
        let input = try recipe.from.makeTexture()
        let compiled = [try recipe.makeFilter()] + filters
        let plan = GraphCompiler.compile(
            filters: compiled,
            inputSize: C7Size(width: input.width, height: input.height),
            profile: recipe.profile,
            derivative: recipe.derivative,
            compilationSource: .transition,
            sourceDescriptor: recipe.from.descriptor,
            auxiliaryInputDescriptor: recipe.to.descriptor
        )
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.recordRenderStageCount(identifier, stageCount: plan.optimizedStages.count)
            if plan.requiresCompletedGPUWork {
                Shared.shared.performanceMonitor?.recordReadbackBoundary(identifier)
            }
        }
        return plan.diagnostics
    }

    public func renderTransitionDiagnosticsJSONData(_ recipe: TransitionRecipe,
                                                    prettyPrinted: Bool = false,
                                                    sortedKeys: Bool = true) throws -> Data {
        try renderTransitionDiagnostics(recipe)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderTransitionDiagnosticsJSONString(_ recipe: TransitionRecipe,
                                                      prettyPrinted: Bool = false,
                                                      sortedKeys: Bool = true) throws -> String {
        try renderTransitionDiagnostics(recipe)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func renderTransitionFrame(_ recipe: TransitionRecipe,
                                      metadata: [String: String] = [:]) throws -> RenderedFrame {
        try FrameRenderer(
            transitionRecipe: recipe,
            filters: filters,
            identifier: identifier,
            metadata: metadata
        ).renderFrame()
    }

    /// texture-first 异步帧输出。需要 UIImage/CGImage/Data 的调用方
    /// 应走读回路径并等待 GPU 完成。
    public func transmitFrame(profile: RenderProfile = .stablePreview,
                              derivative: ImageDerivativeSpec? = nil,
                              metadata: [String: String] = [:],
                              complete: @escaping (Result<RenderedFrame, HarbethError>) -> Void) {
        transmitFrame(
            profile: profile,
            derivative: derivative,
            token: makeFrameRenderToken(),
            metadata: metadata,
            complete: complete
        )
    }

    public func transmitFrame(recipe: EditRecipe,
                              mode: EditRecipeMode = .preview,
                              derivative: ImageDerivativeSpec? = nil,
                              metadata: [String: String] = [:],
                              complete: @escaping (Result<RenderedFrame, HarbethError>) -> Void) {
        transmitFrame(
            recipe: recipe,
            mode: mode,
            derivative: derivative,
            token: makeFrameRenderToken(),
            metadata: metadata,
            complete: complete
        )
    }

    public func transmitFrame(profile: RenderProfile = .stablePreview,
                              derivative: ImageDerivativeSpec? = nil,
                              token: FrameRenderToken,
                              metadata: [String: String] = [:],
                              complete: @escaping (Result<RenderedFrame, HarbethError>) -> Void) {
        do {
            let source = try makeImageSource()
            let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
            FrameRenderer(
                source: source,
                filters: filters,
                profile: profile,
                renderIntent: effectiveDerivative.renderIntent,
                identifier: identifier,
                metadata: metadata,
                outputSemantic: effectiveDerivative.semantic,
                outputDerivative: effectiveDerivative
            ).transmitFrame(token: token, complete: complete)
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }

    public func transmitFrame(recipe: EditRecipe,
                              mode: EditRecipeMode = .preview,
                              derivative: ImageDerivativeSpec? = nil,
                              token: FrameRenderToken,
                              metadata: [String: String] = [:],
                              complete: @escaping (Result<RenderedFrame, HarbethError>) -> Void) {
        do {
            let source = try makeImageSource()
            FrameRenderer(
                source: source,
                recipe: recipe,
                mode: mode,
                filters: filters,
                identifier: identifier,
                metadata: metadata,
                derivative: derivative
            ).transmitFrame(token: token, complete: complete)
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }

    public func transmitTransitionFrame(_ recipe: TransitionRecipe,
                                        metadata: [String: String] = [:],
                                        complete: @escaping (Result<RenderedFrame, HarbethError>) -> Void) {
        FrameRenderer(
            transitionRecipe: recipe,
            filters: filters,
            identifier: identifier,
            metadata: metadata
        ).transmitFrame(complete: complete)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension HarbethIO {
    public func transmitOutput() async throws -> Dest {
        try await withCheckedThrowingContinuation { continuation in
            transmitOutput(complete: { result in
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            })
        }
    }

    public func transmitFrame(profile: RenderProfile = .stablePreview,
                              derivative: ImageDerivativeSpec? = nil,
                              metadata: [String: String] = [:]) async throws -> RenderedFrame {
        try await transmitFrame(
            profile: profile,
            derivative: derivative,
            token: makeFrameRenderToken(),
            metadata: metadata
        )
    }

    public func transmitFrame(profile: RenderProfile = .stablePreview,
                              derivative: ImageDerivativeSpec? = nil,
                              token: FrameRenderToken,
                              metadata: [String: String] = [:]) async throws -> RenderedFrame {
        try await withCheckedThrowingContinuation { continuation in
            transmitFrame(profile: profile, derivative: derivative, token: token, metadata: metadata) { result in
                switch result {
                case .success(let frame):
                    continuation.resume(returning: frame)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func transmitFrame(recipe: EditRecipe,
                              mode: EditRecipeMode = .preview,
                              derivative: ImageDerivativeSpec? = nil,
                              metadata: [String: String] = [:]) async throws -> RenderedFrame {
        try await withCheckedThrowingContinuation { continuation in
            transmitFrame(recipe: recipe, mode: mode, derivative: derivative, metadata: metadata) { result in
                switch result {
                case .success(let frame):
                    continuation.resume(returning: frame)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func transmitTransitionFrame(_ recipe: TransitionRecipe,
                                        metadata: [String: String] = [:]) async throws -> RenderedFrame {
        try await withCheckedThrowingContinuation { continuation in
            transmitTransitionFrame(recipe, metadata: metadata) { result in
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

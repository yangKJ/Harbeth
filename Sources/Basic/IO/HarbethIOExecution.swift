//
//  HarbethIOExecution.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import MetalKit

extension HarbethIO {

    func resolvedOutputColorSpace(inputSize: C7Size, outputColorSpace: ImageColorSpaceContract? = nil) -> ImageColorSpaceContract {
        outputColorSpace ?? filters.reduce(.preserveInput) { current, filter in
            let declared = filter.kernelDescriptor(inputSize: inputSize).outputContract.colorSpace
            return declared.preservesInput ? current : declared
        }
    }

    func makeEffectiveFilters(inputSize: C7Size, derivative: ImageDerivativeSpec) -> [C7FilterProtocol] {
        let baseOutputSize = filters.reduce(inputSize) { size, filter in filter.resize(input: size) }
        let targetOutputSize = derivative.resolvedOutputSize(for: baseOutputSize)
        guard targetOutputSize != baseOutputSize else { return filters }
        return filters + [C7Resize(width: Float(targetOutputSize.width), height: Float(targetOutputSize.height))]
    }

    func makeImageSource() throws -> ImageSource {
        switch element {
        case let texture as MTLTexture:
            return .texture(texture)
        case let image as C7Image:
            return .image(image)
        case let image as CIImage:
            return .ciImage(image)
        case let data as Data:
            return .data(data)
        case let url as URL:
            return .asset(ImageAsset(storage: .url(url)))
        case let asset as ImageAsset:
            return .asset(asset)
        case let value where CFGetTypeID(value as CFTypeRef) == CGImage.typeID:
            return .cgImage(value as! CGImage)
        case let value where CFGetTypeID(value as CFTypeRef) == CVPixelBufferGetTypeID():
            return .pixelBuffer(value as! CVPixelBuffer)
        case let value where CFGetTypeID(value as CFTypeRef) == CMSampleBufferGetTypeID():
            return .sampleBuffer(value as! CMSampleBuffer)
        default:
            throw HarbethError.source2Texture
        }
    }

    func configured(for profile: RenderProfile) -> Self {
        var copy = self
        copy.renderProfile = profile
        copy.enableDoubleBuffer = profile.enablesDoubleBuffer
        copy.createDestTexture = profile.createsDestinationTexture
        return copy
    }

    /// texture-first 同步输出，不执行 CPU 读回。
    func renderTexture(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        let context = try resolvedExecutionContext(profile: profile, derivative: derivative)
        guard context.effectiveFilters.isEmpty == false else {
            return context.sourceTexture
        }
        return try HarbethIO<MTLTexture>(element: context.sourceTexture, filters: context.effectiveFilters)
            .configured(for: profile)
            .output()
    }

    /// 将单帧渲染结果输出为新的 `CVPixelBuffer`，不修改输入 pixel buffer。
    func renderPixelBuffer(profile: RenderProfile = .stablePreview,
                           derivative: ImageDerivativeSpec? = nil,
                           pool: PixelBufferPool? = nil,
                           pixelFormatType: OSType = kCVPixelFormatType_32BGRA,
                           outputPixelFormat: PixelFormatContract = .preserveInput,
                           outputColorSpace: ImageColorSpaceContract? = nil) throws -> CVPixelBuffer {
        let result = try renderTextureForPixelBuffer(
            profile: profile,
            derivative: derivative,
            requestedPixelFormatType: pixelFormatType,
            outputPixelFormat: outputPixelFormat,
            outputColorSpace: outputColorSpace
        )
        let texture = result.texture
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
        pixelBuffer.c7.setColorSpaceAttachments(result.outputColorSpace)
        return pixelBuffer
    }

    /// texture-first task output for callers that need to observe GPU completion.
    func startRenderTextureTask(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderTask<MTLTexture> {
        let context = try resolvedExecutionContext(profile: profile, derivative: derivative)
        let io = HarbethIO<MTLTexture>(
            element: context.sourceTexture,
            filters: context.effectiveFilters,
            identifier: identifier
        ).configured(for: profile)
        let program = io.makeRenderProgram(
            input: context.sourceTexture,
            derivative: context.effectiveDerivative,
            sourceDescriptor: context.sourceObject.descriptor
        )
        guard context.effectiveFilters.isEmpty == false else {
            return .completed(identifier: identifier, output: context.sourceTexture, diagnostics: program.diagnostics)
        }
        return try io.startCompiledRenderTextureTask(program: program)
    }

    /// 结构化渲染计划诊断，供上层做日志、调度、缓存和大图策略分析。
    func renderDiagnostics(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        let context = try resolvedExecutionContext(profile: profile, derivative: derivative)
        let io = HarbethIO<MTLTexture>(
            element: context.sourceTexture,
            filters: context.effectiveFilters,
            identifier: identifier
        ).configured(for: profile)
        let program = io.makeRenderProgram(
            input: context.sourceTexture,
            derivative: context.effectiveDerivative,
            sourceDescriptor: context.sourceObject.descriptor
        )
        if HarbethContext.shared.enablePerformanceMonitor {
            HarbethContext.shared.performanceMonitor.recordRenderStageCount(
                identifier,
                stageCount: program.plan.optimizedStages.count
            )
            if program.plan.requiresCompletedGPUWork {
                HarbethContext.shared.performanceMonitor.recordReadbackBoundary(identifier)
            }
        }
        return program.diagnostics
    }

    func renderDiagnosticsJSONData(profile: RenderProfile = .stablePreview,
                                   derivative: ImageDerivativeSpec? = nil,
                                   prettyPrinted: Bool = false,
                                   sortedKeys: Bool = true) throws -> Data {
        try renderDiagnostics(profile: profile, derivative: derivative)
            .jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    func renderDiagnosticsJSONString(profile: RenderProfile = .stablePreview,
                                     derivative: ImageDerivativeSpec? = nil,
                                     prettyPrinted: Bool = false,
                                     sortedKeys: Bool = true) throws -> String {
        try renderDiagnostics(profile: profile, derivative: derivative)
            .jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    func renderRecipe(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRecipe {
        let context = try resolvedExecutionContext(profile: profile, derivative: derivative)
        let outputCachePolicy: ImageCachePolicy = context.effectiveFilters.isEmpty ? context.sourceObject.cachePolicy : .transient
        return RenderRecipe(
            renderProfile: String(describing: profile),
            renderIntent: context.effectiveDerivative.renderIntent,
            source: context.sourceObject.descriptor,
            outputDerivative: context.effectiveDerivative,
            outputCachePolicy: outputCachePolicy,
            outputSemantic: context.effectiveDerivative.semantic,
            alphaType: context.sourceObject.alphaType,
            orientation: context.sourceObject.orientation,
            filters: context.effectiveFilters.map(\.recipeDescriptor),
            localEffects: nil,
            layerMasks: nil
        )
    }

    func makeRenderRequest(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRequest {
        let context = try resolvedExecutionContext(profile: profile, derivative: derivative)
        let outputCachePolicy: ImageCachePolicy = context.effectiveFilters.isEmpty ? context.sourceObject.cachePolicy : .transient
        let renderRecipe = RenderRecipe(
            renderProfile: String(describing: profile),
            renderIntent: context.effectiveDerivative.renderIntent,
            source: context.sourceObject.descriptor,
            outputDerivative: context.effectiveDerivative,
            outputCachePolicy: outputCachePolicy,
            outputSemantic: context.effectiveDerivative.semantic,
            alphaType: context.sourceObject.alphaType,
            orientation: context.sourceObject.orientation,
            filters: context.effectiveFilters.map(\.recipeDescriptor),
            localEffects: nil,
            layerMasks: nil
        )
        let io = HarbethIO<MTLTexture>(
            element: context.sourceTexture,
            filters: context.effectiveFilters,
            identifier: identifier
        ).configured(for: profile)
        let program = io.makeRenderProgram(
            input: context.sourceTexture,
            derivative: context.effectiveDerivative,
            sourceDescriptor: context.sourceObject.descriptor
        )
        let renderFrame: ([String: String]) throws -> RenderedFrame = { metadata in
            var preparedMetadata = metadata
            preparedMetadata["renderExecutionFingerprint"] = program.fingerprint
            preparedMetadata["renderGraphFingerprint"] = program.diagnostics.graphFingerprint
            let frameRenderer = FrameRenderer(
                source: context.sourceObject,
                filters: context.effectiveFilters,
                profile: profile,
                renderIntent: context.effectiveDerivative.renderIntent,
                identifier: identifier,
                metadata: preparedMetadata,
                outputSemantic: context.effectiveDerivative.semantic,
                outputDerivative: context.effectiveDerivative
            )
            let rendered = try io.renderManagedTexture(program: program)
            return try frameRenderer.materializeFrame(
                renderedTexture: rendered.texture,
                lease: rendered.lease,
                token: frameRenderer.makeToken()
            )
        }
        // Attachment inspection belongs to the final render primitive itself. A derivative
        // resize is a delivery step after that primitive, so it must not replace this route.
        let preparedAttachmentFilter = filters.last as? any RenderProtocol
        let preparedAttachmentInput: (() throws -> MTLTexture)?
        if preparedAttachmentFilter != nil {
            let preFilters = Array(filters.dropLast())
            if preFilters.isEmpty {
                preparedAttachmentInput = { context.sourceTexture }
            } else {
                let preIO = HarbethIO<MTLTexture>(
                    element: context.sourceTexture,
                    filters: preFilters,
                    identifier: "\(identifier).preparedAttachment"
                ).configured(for: profile)
                let preProgram = preIO.makeRenderProgram(
                    input: context.sourceTexture,
                    derivative: profile.defaultDerivativeSpec,
                    sourceDescriptor: context.sourceObject.descriptor
                )
                preparedAttachmentInput = {
                    try preIO.executeRenderProgram(input: context.sourceTexture, program: preProgram)
                }
            }
        } else {
            preparedAttachmentInput = nil
        }
        let attachmentDebugPolicies = preparedAttachmentFilter?
            .renderOutputContract.attachments.map(\.debugPolicy)
            ?? program.diagnostics.outputAttachmentDebugPolicies
        return RenderRequest.makeFrameBackedRequest(
            compilationSource: .filtersPrimitive,
            profile: profile,
            derivative: context.effectiveDerivative,
            source: context.sourceObject.descriptor,
            outputCachePolicy: outputCachePolicy,
            diagnostics: program.diagnostics,
            renderRecipe: renderRecipe,
            renderTexture: {
                if context.effectiveFilters.isEmpty {
                    return context.sourceTexture
                }
                return try io.executeRenderProgram(input: context.sourceTexture, program: program)
            },
            renderFrame: renderFrame,
            attachmentDebugPolicies: attachmentDebugPolicies,
            renderAttachmentSet: {
                guard let preparedAttachmentFilter, let preparedAttachmentInput else { return nil }
                return try preparedAttachmentFilter.renderAttachmentSet(
                    from: preparedAttachmentInput(),
                    identifier: "\(identifier).attachmentSet"
                )
            },
            renderAttachmentAnalysisBundle: { bins, histogramHeight, region, preferredMethod in
                guard let preparedAttachmentFilter, let preparedAttachmentInput else { return nil }
                return try preparedAttachmentFilter.renderAttachmentAnalysisBundle(
                    from: preparedAttachmentInput(),
                    identifier: "\(identifier).attachmentAnalysis",
                    bins: bins,
                    histogramHeight: histogramHeight,
                    region: region,
                    preferredMethod: preferredMethod
                )
            },
            renderAttachmentAnalysisScopeBundle: { bins, histogramHeight, scope, preferredMethod in
                guard let preparedAttachmentFilter, let preparedAttachmentInput else { return nil }
                return try preparedAttachmentFilter.renderAttachmentAnalysisBundle(
                    from: preparedAttachmentInput(),
                    identifier: "\(identifier).attachmentAnalysis",
                    bins: bins,
                    histogramHeight: histogramHeight,
                    scope: scope,
                    preferredMethod: preferredMethod
                )
            }
        )
    }

    /// 直接渲染 filters 路径最终结果并输出 histogram。
    ///
    /// 这个入口保持 Harbeth 的轻量使用方式：
    /// 上层不需要先手动拿 frame/texture 再做一次 histogram 读回。
    func renderHistogram(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        coverageThreshold: Float = 0.5,
        preferredMethod: TextureHistogramComputationMethod = .cpuReadback
    ) throws -> TextureHistogram? {
        try renderFrame(profile: profile, derivative: derivative).makeHistogram(
            channel: channel,
            bins: bins,
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func renderHistogramAttachment(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        height: Int = 64,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        coverageThreshold: Float = 0.5,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedHistogramAttachment? {
        try renderFrame(profile: profile, derivative: derivative).renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func renderAnalysisBundle(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        histogramHeight: Int = 64,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        luminanceRange: TextureLuminanceRange? = nil,
        coverageThreshold: Float = 0.5,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAnalysisBundle {
        let frame = try renderFrame(profile: profile, derivative: derivative)
        let histogramAttachment = frame.renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: histogramHeight,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
            channel: channel,
            bins: bins,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
        let statistics = frame.makeStatistics(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            coverageThreshold: coverageThreshold
        )
        let colorProbe = frame.makeColorProbe(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            coverageThreshold: coverageThreshold
        )
        return RenderedAnalysisBundle(
            frame: frame,
            histogram: histogram,
            statistics: statistics,
            colorProbe: colorProbe,
            histogramAttachment: histogramAttachment,
            analysisScopeFingerprint: TextureAnalysisScope(
                region: region,
                mask: mask,
                luminanceRange: luminanceRange,
                coverageThreshold: coverageThreshold
            ).fingerprint,
            attachmentDebugPolicies: [RenderOutputAttachmentContract(index: 0).debugPolicy]
        )
    }

    func renderAnalysisBundle(
        profile: RenderProfile = .readbackQuality,
        derivative: ImageDerivativeSpec? = nil,
        channel: TextureHistogramChannel = .luminance,
        bins: Int = 256,
        histogramHeight: Int = 64,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAnalysisBundle {
        let frame = try renderFrame(profile: profile, derivative: derivative)
        let histogramAttachment = frame.renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
            channel: channel,
            bins: bins,
            scope: scope,
            preferredMethod: preferredMethod
        )
        let statistics = frame.makeStatistics(scope: scope)
        let colorProbe = frame.makeColorProbe(scope: scope)
        return RenderedAnalysisBundle(
            frame: frame,
            histogram: histogram,
            statistics: statistics,
            colorProbe: colorProbe,
            histogramAttachment: histogramAttachment,
            analysisScopeFingerprint: scope.fingerprint,
            attachmentDebugPolicies: [RenderOutputAttachmentContract(index: 0).debugPolicy]
        )
    }

    /// 当 filter 链最后一个节点是真正的 render primitive 时，
    /// 直接返回多 attachment 的轻量输出集合。
    ///
    /// 这个入口不会把普通 filter 链强行提升成 MRT runtime；
    /// 只有末端是 `RenderProtocol` 时才返回 attachment set。
    func renderAttachmentSet(profile: RenderProfile = .readbackQuality) throws -> RenderedAttachmentSet? {
        guard let finalFilter = filters.last as? any RenderProtocol else { return nil }
        let source = try makeImageSource()
        let inputTexture: MTLTexture
        if filters.count > 1 {
            let preFilters = Array(filters.dropLast())
            inputTexture = try HarbethIO<MTLTexture>(element: try source.makeTexture(), filters: preFilters)
                .configured(for: profile)
                .output()
        } else {
            inputTexture = try source.makeTexture()
        }
        return try finalFilter.renderAttachmentSet(from: inputTexture, identifier: "\(identifier).attachmentSet")
    }

    /// 当 filter 链最后一个节点是真正的 render primitive 时，
    /// 直接返回多 attachment 的轻量分析输出集合。
    ///
    /// 这个入口不会把普通 filter 链强行提升成 MRT runtime；
    /// 只有末端是 `RenderProtocol` 时才返回 bundle。
    func renderAttachmentAnalysisBundle(
        profile: RenderProfile = .readbackQuality,
        bins: Int = 256,
        histogramHeight: Int = 64,
        region: MTLRegion? = nil,
        mask: MaskDescriptor? = nil,
        coverageThreshold: Float = 0.5,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAttachmentAnalysisBundle? {
        guard let finalFilter = filters.last as? any RenderProtocol else {
            return nil
        }
        let source = try makeImageSource()
        let inputTexture: MTLTexture
        if filters.count > 1 {
            let preFilters = Array(filters.dropLast())
            inputTexture = try HarbethIO<MTLTexture>(element: try source.makeTexture(), filters: preFilters)
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
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func renderAttachmentAnalysisBundle(
        profile: RenderProfile = .readbackQuality,
        bins: Int = 256,
        histogramHeight: Int = 64,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod = .gpuMPS
    ) throws -> RenderedAttachmentAnalysisBundle? {
        guard let finalFilter = filters.last as? any RenderProtocol else { return nil }
        let source = try makeImageSource()
        let inputTexture: MTLTexture
        if filters.count > 1 {
            let preFilters = Array(filters.dropLast())
            inputTexture = try HarbethIO<MTLTexture>(element: try source.makeTexture(), filters: preFilters)
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
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    /// texture-first 同步帧输出，携带稳定元数据。
    func renderFrame(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        outputColorSpace: ImageColorSpaceContract? = nil,
        metadata: [String: String] = [:]
    ) throws -> RenderedFrame {
        let source = try makeImageSource()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let renderer = FrameRenderer(
            source: source,
            filters: filters,
            profile: profile,
            renderIntent: effectiveDerivative.renderIntent,
            identifier: identifier,
            metadata: metadata,
            outputColorSpace: outputColorSpace,
            outputSemantic: effectiveDerivative.semantic,
            outputDerivative: effectiveDerivative
        )
        return try renderer.renderFrame()
    }

    func makeFrameRenderToken() -> FrameRenderToken {
        FrameRenderToken(identifier: identifier, generation: FrameGeneration.next())
    }

    func renderFrame(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        token: FrameRenderToken,
        outputColorSpace: ImageColorSpaceContract? = nil,
        metadata: [String: String] = [:]
    ) throws -> RenderedFrame {
        let source = try makeImageSource()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        return try FrameRenderer(
            source: source,
            filters: filters,
            profile: profile,
            renderIntent: effectiveDerivative.renderIntent,
            identifier: identifier,
            metadata: metadata,
            outputColorSpace: outputColorSpace,
            outputSemantic: effectiveDerivative.semantic,
            outputDerivative: effectiveDerivative
        ).renderFrame(token: token)
    }

    /// texture-first 异步帧输出。需要 UIImage/CGImage/Data 的调用方
    /// 应走读回路径并等待 GPU 完成。
    func transmitFrame(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        outputColorSpace: ImageColorSpaceContract? = nil,
        metadata: [String: String] = [:],
        complete: @escaping @Sendable (Result<RenderedFrame, HarbethError>) -> Void
    ) {
        transmitFrame(
            profile: profile,
            derivative: derivative,
            token: makeFrameRenderToken(),
            outputColorSpace: outputColorSpace,
            metadata: metadata,
            complete: complete
        )
    }

    func transmitFrame(
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        token: FrameRenderToken,
        outputColorSpace: ImageColorSpaceContract? = nil,
        metadata: [String: String] = [:],
        complete: @escaping @Sendable (Result<RenderedFrame, HarbethError>) -> Void
    ) {
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
                outputColorSpace: outputColorSpace,
                outputSemantic: effectiveDerivative.semantic,
                outputDerivative: effectiveDerivative
            ).transmitFrame(token: token, complete: complete)
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }

}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
extension HarbethIO {
    func transmitFrame(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil, metadata: [String: String] = [:]) async throws -> RenderedFrame {
        try await transmitFrame(
            profile: profile,
            derivative: derivative,
            token: makeFrameRenderToken(),
            metadata: metadata
        )
    }

    func transmitFrame(
profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        token: FrameRenderToken,
        metadata: [String: String] = [:]
    ) async throws -> RenderedFrame {
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
}

extension HarbethIO {
    private func resolvedExecutionContext(
        profile: RenderProfile,
        derivative: ImageDerivativeSpec? = nil
    ) throws -> (
        sourceObject: ImageSource,
        sourceTexture: MTLTexture,
        effectiveDerivative: ImageDerivativeSpec,
        effectiveFilters: [C7FilterProtocol]
    ) {
        let sourceObject = try makeImageSource()
        let sourceTexture = try sourceObject.makeTexture()
        let effectiveDerivative = derivative ?? profile.defaultDerivativeSpec
        let effectiveFilters = makeEffectiveFilters(
            inputSize: C7Size(texture: sourceTexture),
            derivative: effectiveDerivative
        )
        return (sourceObject, sourceTexture, effectiveDerivative, effectiveFilters)
    }

    private func renderTextureForPixelBuffer(
        profile: RenderProfile,
        derivative: ImageDerivativeSpec?,
        requestedPixelFormatType: OSType,
        outputPixelFormat: PixelFormatContract,
        outputColorSpace: ImageColorSpaceContract? = nil
    ) throws -> (texture: MTLTexture, outputColorSpace: ImageColorSpaceContract) {
        let context = try resolvedExecutionContext(profile: profile, derivative: derivative)
        var effectiveFilters = context.effectiveFilters
        let targetPixelFormat: MTLPixelFormat? = {
            if outputPixelFormat.preservesInput {
                switch requestedPixelFormatType {
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
            return outputPixelFormat.metalPixelFormat
        }()
        if effectiveFilters.isEmpty, let targetPixelFormat, context.sourceTexture.pixelFormat != targetPixelFormat {
            effectiveFilters = [C7Brightness(brightness: 0)]
        }
        guard effectiveFilters.isEmpty == false else {
            return (context.sourceTexture, outputColorSpace ?? .preserveInput)
        }
        var io = HarbethIO<MTLTexture>(element: context.sourceTexture, filters: effectiveFilters)
            .configured(for: profile)
        if let targetPixelFormat {
            io.bufferPixelFormat = targetPixelFormat
            io.createDestTexture = true
        }
        let outputColorSpace = io.resolvedOutputColorSpace(
            inputSize: C7Size(texture: context.sourceTexture),
            outputColorSpace: outputColorSpace
        )
        let texture = try io.output()
        return (texture, outputColorSpace)
    }

    private func resolvePixelBufferFormatType(requestedPixelFormatType: OSType, outputPixelFormat: PixelFormatContract, renderedTexture: MTLTexture) throws -> OSType {
        if outputPixelFormat.preservesInput {
            return requestedPixelFormatType
        }
        guard let targetPixelFormat = outputPixelFormat.metalPixelFormat else {
            throw HarbethError.configurationInvalid(
                "Pixel buffer output pixel format contract must resolve to a Metal pixel format."
            )
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
}

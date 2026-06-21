//
//  HarbethIO+Frame.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
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
        let sourceObject = try makeHarbethSource()
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
                                  pool: HarbethPixelBufferPool? = nil,
                                  pixelFormatType: OSType = kCVPixelFormatType_32BGRA) throws -> CVPixelBuffer {
        let texture = try renderTexture(profile: profile, derivative: derivative)
        let outputPool = try pool ?? HarbethPixelBufferPool(
            width: texture.width,
            height: texture.height,
            pixelFormatType: pixelFormatType
        )
        let pixelBuffer = try outputPool.makePixelBuffer()
        guard CVPixelBufferGetWidth(pixelBuffer) == texture.width,
              CVPixelBufferGetHeight(pixelBuffer) == texture.height else {
            throw HarbethError.textureSizeMismatch
        }
        guard pixelBuffer.c7.copyToPixelBuffer(with: texture) else {
            throw HarbethError.pixelBufferCopyFailed
        }
        return pixelBuffer
    }

    /// texture-first task output for callers that need to observe GPU completion.
    public func startRenderTextureTask(profile: RenderProfile = .stablePreview,
                                       derivative: ImageDerivativeSpec? = nil) throws -> HarbethRenderTask<MTLTexture> {
        let sourceObject = try makeHarbethSource()
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
            compilationSource: .filtersPrimitive
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
        let source = try makeHarbethSource().makeTexture()
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: source.width, height: source.height),
            profile: profile,
            derivative: derivative ?? profile.defaultDerivativeSpec,
            compilationSource: .filtersPrimitive
        )
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.recordRenderStageCount(identifier, stageCount: plan.optimizedStages.count)
            if plan.requiresCompletedGPUWork {
                Shared.shared.performanceMonitor?.recordReadbackBoundary(identifier)
            }
        }
        return plan.diagnostics
    }

    public func renderRecipe(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderRecipe {
        let source = try makeHarbethSource()
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

    public func renderTexture(recipe: EditRecipe,
                              mode: EditRecipeMode = .preview,
                              derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        let source = try makeHarbethSource()
        return try FrameRenderer(
            source: source,
            recipe: recipe,
            mode: mode,
            filters: filters,
            identifier: identifier,
            derivative: derivative
        ).renderTexture()
    }

    public func renderTexture(node: HarbethImageNode,
                              profile: RenderProfile = .stablePreview,
                              derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        try node.makeTexture(profile: profile, derivative: derivative)
    }

    public func renderDiagnostics(recipe: EditRecipe,
                                  mode: EditRecipeMode = .preview,
                                  derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        let plan = try recipe.makeRenderPlan(
            source: makeHarbethSource(),
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

    public func renderTexture(composite recipe: LayerCompositeRecipe,
                              derivative: ImageDerivativeSpec? = nil) throws -> MTLTexture {
        try recipe.makeTexture(derivative: derivative)
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

    public func renderFrame(composite recipe: LayerCompositeRecipe,
                            derivative: ImageDerivativeSpec? = nil,
                            metadata: [String: String] = [:]) throws -> RenderedFrame {
        try recipe.makeNode().makeFrame(
            profile: recipe.profile,
            derivative: derivative ?? recipe.derivative,
            metadata: metadata
        )
    }

    public func renderDiagnostics(node: HarbethImageNode,
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

    /// texture-first 同步帧输出，携带稳定元数据。
    public func renderFrame(profile: RenderProfile = .stablePreview,
                            derivative: ImageDerivativeSpec? = nil,
                            metadata: [String: String] = [:]) throws -> RenderedFrame {
        let source = try makeHarbethSource()
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
        let source = try makeHarbethSource()
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

    public func renderFrame(node: HarbethImageNode,
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
        let source = try makeHarbethSource()
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
        let source = try makeHarbethSource()
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
            compilationSource: .transition
        )
        if Shared.shared.enablePerformanceMonitor {
            Shared.shared.performanceMonitor?.recordRenderStageCount(identifier, stageCount: plan.optimizedStages.count)
            if plan.requiresCompletedGPUWork {
                Shared.shared.performanceMonitor?.recordReadbackBoundary(identifier)
            }
        }
        return plan.diagnostics
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
            let source = try makeHarbethSource()
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
            let source = try makeHarbethSource()
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

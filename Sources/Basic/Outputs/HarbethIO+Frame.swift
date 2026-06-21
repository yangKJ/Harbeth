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

    /// 结构化渲染计划诊断，供上层做日志、调度、缓存和大图策略分析。
    public func renderDiagnostics(profile: RenderProfile = .stablePreview, derivative: ImageDerivativeSpec? = nil) throws -> RenderPlanDiagnostics {
        let source = try makeHarbethSource().makeTexture()
        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: source.width, height: source.height),
            profile: profile,
            derivative: derivative ?? profile.defaultDerivativeSpec
        )
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
}

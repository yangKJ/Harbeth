//
//  RenderRequest.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

/// A deferred single-frame render contract that can be compiled first and executed later.
public struct RenderRequest {
    public let compilationSource: RenderCompilationSource
    public let profile: RenderProfile
    public let derivative: ImageDerivativeSpec
    public let source: ImageSourceDescriptor
    public let outputCachePolicy: ImageCachePolicy
    public let diagnostics: RenderPlanDiagnostics
    let renderRecipe: RenderRecipe?

    private let renderTextureClosure: () throws -> MTLTexture
    private let renderFrameClosure: ([String: String]) throws -> RenderedFrame
    private let renderAnalysisBundleClosure: ((TextureHistogramChannel, Int, Int, MTLRegion?, TextureHistogramComputationMethod) throws -> RenderedAnalysisBundle)?
    private let renderAnalysisScopeBundleClosure: ((TextureHistogramChannel, Int, Int, TextureAnalysisScope, TextureHistogramComputationMethod) throws -> RenderedAnalysisBundle)?
    private let renderAttachmentSetClosure: (() throws -> RenderedAttachmentSet?)?
    private let renderAttachmentAnalysisBundleClosure: ((Int, Int, MTLRegion?, TextureHistogramComputationMethod) throws -> RenderedAttachmentAnalysisBundle?)?
    private let renderAttachmentAnalysisScopeBundleClosure: ((Int, Int, TextureAnalysisScope, TextureHistogramComputationMethod) throws -> RenderedAttachmentAnalysisBundle?)?

    init(compilationSource: RenderCompilationSource,
         profile: RenderProfile,
         derivative: ImageDerivativeSpec,
         source: ImageSourceDescriptor,
         outputCachePolicy: ImageCachePolicy,
         diagnostics: RenderPlanDiagnostics,
         renderRecipe: RenderRecipe?,
         renderTexture: @escaping () throws -> MTLTexture,
         renderFrame: @escaping ([String: String]) throws -> RenderedFrame,
         renderAnalysisBundle: ((TextureHistogramChannel, Int, Int, MTLRegion?, TextureHistogramComputationMethod) throws -> RenderedAnalysisBundle)? = nil,
         renderAnalysisScopeBundle: ((TextureHistogramChannel, Int, Int, TextureAnalysisScope, TextureHistogramComputationMethod) throws -> RenderedAnalysisBundle)? = nil,
         renderAttachmentSet: (() throws -> RenderedAttachmentSet?)? = nil,
         renderAttachmentAnalysisBundle: ((Int, Int, MTLRegion?, TextureHistogramComputationMethod) throws -> RenderedAttachmentAnalysisBundle?)? = nil,
         renderAttachmentAnalysisScopeBundle: ((Int, Int, TextureAnalysisScope, TextureHistogramComputationMethod) throws -> RenderedAttachmentAnalysisBundle?)? = nil) {
        self.compilationSource = compilationSource
        self.profile = profile
        self.derivative = derivative
        self.source = source
        self.outputCachePolicy = outputCachePolicy
        self.diagnostics = diagnostics
        self.renderRecipe = renderRecipe
        self.renderTextureClosure = renderTexture
        self.renderFrameClosure = renderFrame
        self.renderAnalysisBundleClosure = renderAnalysisBundle
        self.renderAnalysisScopeBundleClosure = renderAnalysisScopeBundle
        self.renderAttachmentSetClosure = renderAttachmentSet
        self.renderAttachmentAnalysisBundleClosure = renderAttachmentAnalysisBundle
        self.renderAttachmentAnalysisScopeBundleClosure = renderAttachmentAnalysisScopeBundle
    }

    public func renderTexture() throws -> MTLTexture {
        try renderTextureClosure()
    }

    public func renderFrame(metadata: [String: String] = [:]) throws -> RenderedFrame {
        try renderFrameClosure(metadata)
    }

    public var frameHostSourceDescriptor: FrameHostSourceDescriptor {
        diagnostics.inputFrameHostDescriptor ?? source.frameHostSourceDescriptor
    }

    public var frameHostRuntimeHint: FrameHostRuntimeHint {
        diagnostics.frameHostRuntimeHint
    }

    public func renderAnalysisBundle(channel: TextureHistogramChannel = .luminance,
                                     bins: Int = 256,
                                     histogramHeight: Int = 64,
                                     region: MTLRegion? = nil,
                                     preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle? {
        try renderAnalysisBundleClosure?(channel, bins, histogramHeight, region, preferredMethod)
    }

    public func renderAnalysisBundle(channel: TextureHistogramChannel = .luminance,
                                     bins: Int = 256,
                                     histogramHeight: Int = 64,
                                     scope: TextureAnalysisScope,
                                     preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle? {
        try renderAnalysisScopeBundleClosure?(channel, bins, histogramHeight, scope, preferredMethod)
    }

    public func renderColorProbe(region: MTLRegion? = nil) throws -> TextureColorProbe? {
        try renderAnalysisBundle(region: region, preferredMethod: .cpuReadback)?.colorProbe
    }

    public func renderColorProbe(scope: TextureAnalysisScope) throws -> TextureColorProbe? {
        try renderAnalysisBundle(scope: scope, preferredMethod: .cpuReadback)?.colorProbe
    }

    public func renderColorProbe(x: Int, y: Int, radius: Int = 0) throws -> TextureColorProbe? {
        try renderAnalysisBundle(
            scope: .point(x: x, y: y, radius: radius),
            preferredMethod: .cpuReadback
        )?.colorProbe
    }

    public func renderAttachmentSet() throws -> RenderedAttachmentSet? {
        try renderAttachmentSetClosure?()
    }

    public func renderAttachmentAnalysisBundle(bins: Int = 256,
                                               histogramHeight: Int = 64,
                                               region: MTLRegion? = nil,
                                               preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle? {
        try renderAttachmentAnalysisBundleClosure?(bins, histogramHeight, region, preferredMethod)
    }

    public func renderAttachmentAnalysisBundle(bins: Int = 256,
                                               histogramHeight: Int = 64,
                                               scope: TextureAnalysisScope,
                                               preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle? {
        try renderAttachmentAnalysisScopeBundleClosure?(bins, histogramHeight, scope, preferredMethod)
    }
}

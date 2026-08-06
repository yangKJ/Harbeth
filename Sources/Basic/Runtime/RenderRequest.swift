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
    public let resourceBudget: RenderResourceBudget?
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
         resourceBudget: RenderResourceBudget? = nil,
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
        self.resourceBudget = resourceBudget
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
        try validateResourceAdmission()
        return try renderTextureClosure()
    }

    public func renderFrame(metadata: [String: String] = [:]) throws -> RenderedFrame {
        try validateResourceAdmission()
        var renderedMetadata = metadata
        renderedMetadata["renderParityFingerprint"] = paritySignature.fingerprint
        renderedMetadata["renderResourceEstimate"] = resourceEstimate.fingerprint
        if let resourceBudget {
            renderedMetadata["renderResourceBudget"] = resourceBudget.fingerprint
        }
        return try renderFrameClosure(renderedMetadata)
    }

    public func withResourceBudget(_ budget: RenderResourceBudget?) -> RenderRequest {
        RenderRequest(
            compilationSource: compilationSource,
            profile: profile,
            derivative: derivative,
            source: source,
            outputCachePolicy: outputCachePolicy,
            diagnostics: diagnostics,
            resourceBudget: budget,
            renderRecipe: renderRecipe,
            renderTexture: renderTextureClosure,
            renderFrame: renderFrameClosure,
            renderAnalysisBundle: renderAnalysisBundleClosure,
            renderAnalysisScopeBundle: renderAnalysisScopeBundleClosure,
            renderAttachmentSet: renderAttachmentSetClosure,
            renderAttachmentAnalysisBundle: renderAttachmentAnalysisBundleClosure,
            renderAttachmentAnalysisScopeBundle: renderAttachmentAnalysisScopeBundleClosure
        )
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
        try validateResourceAdmission()
        return try renderAnalysisBundleClosure?(channel, bins, histogramHeight, region, preferredMethod)
    }

    public func renderAnalysisBundle(channel: TextureHistogramChannel = .luminance,
                                     bins: Int = 256,
                                     histogramHeight: Int = 64,
                                     scope: TextureAnalysisScope,
                                     preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAnalysisBundle? {
        try validateResourceAdmission()
        return try renderAnalysisScopeBundleClosure?(channel, bins, histogramHeight, scope, preferredMethod)
    }

    public func renderHistogram(channel: TextureHistogramChannel = .luminance,
                                bins: Int = 256,
                                region: MTLRegion? = nil,
                                preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderFrame().makeHistogram(
            channel: channel,
            bins: bins,
            region: region,
            preferredMethod: preferredMethod
        )
    }

    public func renderHistogram(channel: TextureHistogramChannel = .luminance,
                                bins: Int = 256,
                                scope: TextureAnalysisScope,
                                preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderFrame().makeHistogram(
            channel: channel,
            bins: bins,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func renderStatistics(region: MTLRegion? = nil,
                                 preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureStatistics? {
        try renderFrame().makeStatistics(region: region)
    }

    public func renderStatistics(scope: TextureAnalysisScope,
                                 preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureStatistics? {
        try renderFrame().makeStatistics(scope: scope)
    }

    public func renderColorProbe(region: MTLRegion? = nil) throws -> TextureColorProbe? {
        try renderFrame().makeColorProbe(region: region)
    }

    public func renderColorProbe(scope: TextureAnalysisScope) throws -> TextureColorProbe? {
        try renderFrame().makeColorProbe(scope: scope)
    }

    public func renderColorProbe(x: Int, y: Int, radius: Int = 0) throws -> TextureColorProbe? {
        try renderFrame().makeColorProbe(x: x, y: y, radius: radius)
    }

    public func renderAttachmentSet() throws -> RenderedAttachmentSet? {
        try validateResourceAdmission()
        return try renderAttachmentSetClosure?()
    }

    public func renderAttachmentAnalysisBundle(bins: Int = 256,
                                               histogramHeight: Int = 64,
                                               region: MTLRegion? = nil,
                                               preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle? {
        try validateResourceAdmission()
        return try renderAttachmentAnalysisBundleClosure?(bins, histogramHeight, region, preferredMethod)
    }

    public func renderAttachmentAnalysisBundle(bins: Int = 256,
                                               histogramHeight: Int = 64,
                                               scope: TextureAnalysisScope,
                                               preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle? {
        try validateResourceAdmission()
        return try renderAttachmentAnalysisScopeBundleClosure?(bins, histogramHeight, scope, preferredMethod)
    }

    public func renderAttachment(semantic: RenderOutputAttachmentSemantic) throws -> RenderedAttachment? {
        try renderAttachmentSet()?.attachment(for: semantic)
    }

    public func renderAttachmentAnalysis(semantic: RenderOutputAttachmentSemantic,
                                         bins: Int = 256,
                                         histogramHeight: Int = 64,
                                         region: MTLRegion? = nil,
                                         preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysis? {
        try renderAttachmentAnalysisBundle(
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            preferredMethod: preferredMethod
        )?.analysis(for: semantic)
    }

    public func renderAttachmentAnalysis(semantic: RenderOutputAttachmentSemantic,
                                         bins: Int = 256,
                                         histogramHeight: Int = 64,
                                         scope: TextureAnalysisScope,
                                         preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysis? {
        try renderAttachmentAnalysisBundle(
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod
        )?.analysis(for: semantic)
    }

    public func renderAttachmentHistogram(semantic: RenderOutputAttachmentSemantic,
                                          channel: TextureHistogramChannel? = nil,
                                          bins: Int = 256,
                                          region: MTLRegion? = nil,
                                          preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderAttachmentSet()?.makeHistogram(
            for: semantic,
            channel: channel,
            bins: bins,
            region: region,
            preferredMethod: preferredMethod
        )
    }

    public func renderAttachmentHistogram(semantic: RenderOutputAttachmentSemantic,
                                          channel: TextureHistogramChannel? = nil,
                                          bins: Int = 256,
                                          scope: TextureAnalysisScope,
                                          preferredMethod: TextureHistogramComputationMethod = .cpuReadback) throws -> TextureHistogram? {
        try renderAttachmentSet()?.makeHistogram(
            for: semantic,
            channel: channel,
            bins: bins,
            scope: scope,
            preferredMethod: preferredMethod
        )
    }

    public func renderAttachmentStatistics(semantic: RenderOutputAttachmentSemantic,
                                           region: MTLRegion? = nil,
                                           mask: MaskDescriptor? = nil,
                                           luminanceRange: TextureLuminanceRange? = nil,
                                           colorRange: TextureColorRange? = nil,
                                           coverageThreshold: Float = 0.5) throws -> TextureStatistics? {
        try renderAttachmentSet()?.makeStatistics(
            for: semantic,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func renderAttachmentStatistics(semantic: RenderOutputAttachmentSemantic,
                                           scope: TextureAnalysisScope) throws -> TextureStatistics? {
        try renderAttachmentSet()?.makeStatistics(for: semantic, scope: scope)
    }

    public func renderAttachmentColorProbe(semantic: RenderOutputAttachmentSemantic,
                                           region: MTLRegion? = nil,
                                           mask: MaskDescriptor? = nil,
                                           luminanceRange: TextureLuminanceRange? = nil,
                                           colorRange: TextureColorRange? = nil,
                                           coverageThreshold: Float = 0.5) throws -> TextureColorProbe? {
        try renderAttachmentSet()?.makeColorProbe(
            for: semantic,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    public func renderAttachmentColorProbe(semantic: RenderOutputAttachmentSemantic,
                                           scope: TextureAnalysisScope) throws -> TextureColorProbe? {
        try renderAttachmentSet()?.makeColorProbe(for: semantic, scope: scope)
    }

    public func renderAttachmentMaskDescriptor(semantic: RenderOutputAttachmentSemantic,
                                               scope: TextureAnalysisScope,
                                               component: MaskComponent = .red,
                                               blendMode: MaskBlendMode = .mix,
                                               invert: Bool = false,
                                               featherPolicy: MaskFeatherPolicy = .none,
                                               opacity: Float = 1.0,
                                               pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor? {
        try renderAttachmentSet()?.makeMaskDescriptor(
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
}

extension RenderRequest {
    static func makeFrameBackedRequest(compilationSource: RenderCompilationSource,
                                       profile: RenderProfile,
                                       derivative: ImageDerivativeSpec,
                                       source: ImageSourceDescriptor,
                                       outputCachePolicy: ImageCachePolicy,
                                       diagnostics: RenderPlanDiagnostics,
                                       renderRecipe: RenderRecipe?,
                                       renderTexture: @escaping () throws -> MTLTexture,
                                       renderFrame: @escaping ([String: String]) throws -> RenderedFrame,
                                       attachmentDebugPolicies: [RenderOutputAttachmentDebugPolicy],
                                       renderAttachmentSet: (() throws -> RenderedAttachmentSet?)? = nil,
                                       renderAttachmentAnalysisBundle: ((Int, Int, MTLRegion?, TextureHistogramComputationMethod) throws -> RenderedAttachmentAnalysisBundle?)? = nil,
                                       renderAttachmentAnalysisScopeBundle: ((Int, Int, TextureAnalysisScope, TextureHistogramComputationMethod) throws -> RenderedAttachmentAnalysisBundle?)? = nil) -> RenderRequest {
        RenderRequest(
            compilationSource: compilationSource,
            profile: profile,
            derivative: derivative,
            source: source,
            outputCachePolicy: outputCachePolicy,
            diagnostics: diagnostics,
            renderRecipe: renderRecipe,
            renderTexture: renderTexture,
            renderFrame: renderFrame,
            renderAnalysisBundle: { channel, bins, histogramHeight, region, preferredMethod in
                let frame = try renderFrame([:])
                return RenderedAnalysisBundle.makeRegionBundle(
                    frame: frame,
                    channel: channel,
                    bins: bins,
                    histogramHeight: histogramHeight,
                    region: region,
                    preferredMethod: preferredMethod,
                    attachmentDebugPolicies: attachmentDebugPolicies
                )
            },
            renderAnalysisScopeBundle: { channel, bins, histogramHeight, scope, preferredMethod in
                let frame = try renderFrame([:])
                return RenderedAnalysisBundle.makeScopeBundle(
                    frame: frame,
                    channel: channel,
                    bins: bins,
                    histogramHeight: histogramHeight,
                    scope: scope,
                    preferredMethod: preferredMethod,
                    attachmentDebugPolicies: attachmentDebugPolicies
                )
            },
            renderAttachmentSet: renderAttachmentSet,
            renderAttachmentAnalysisBundle: renderAttachmentAnalysisBundle,
            renderAttachmentAnalysisScopeBundle: renderAttachmentAnalysisScopeBundle
        )
    }

}

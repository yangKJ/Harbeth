//
//  RenderedAttachmentAnalysisBundle.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import CoreGraphics
import Metal

/// 单个 attachment 的稳定分析结果。
public struct RenderedAttachmentAnalysis: @unchecked Sendable {
    public let attachment: RenderedAttachment
    public let histogram: TextureHistogram?
    public let statistics: TextureStatistics?
    public let histogramAttachment: RenderedHistogramAttachment?

    public init(attachment: RenderedAttachment,
                histogram: TextureHistogram?,
                statistics: TextureStatistics?,
                histogramAttachment: RenderedHistogramAttachment?) {
        self.attachment = attachment
        self.histogram = histogram
        self.statistics = statistics
        self.histogramAttachment = histogramAttachment
    }

    public func makeCGImage(colorSpace: CGColorSpace? = nil,
                            alphaType: AlphaType = .premultiplied) -> CGImage? {
        attachment.makeCGImage(colorSpace: colorSpace, alphaType: alphaType)
    }

    public func makeHistogramCGImage(colorSpace: CGColorSpace? = nil,
                                     alphaType: AlphaType = .premultiplied) -> CGImage? {
        histogramAttachment?.makeCGImage(colorSpace: colorSpace, alphaType: alphaType)
    }
}

/// 一次 MRT render 的轻量分析导出集合。
///
/// 它不替代 `RenderedAttachmentSet`，而是在需要一次拿到主图、辅助 attachment、
/// histogram 数据和 histogram preview 时，提供一个更完整但仍轻量的底座导出面。
public struct RenderedAttachmentAnalysisBundle: @unchecked Sendable {
    public let attachmentSet: RenderedAttachmentSet
    public let analyses: [RenderedAttachmentAnalysis]
    public let analysisScopeFingerprint: String?

    public init(attachmentSet: RenderedAttachmentSet,
                analyses: [RenderedAttachmentAnalysis],
                analysisScopeFingerprint: String? = nil) {
        self.attachmentSet = attachmentSet
        self.analyses = analyses.sorted { $0.attachment.index < $1.attachment.index }
        self.analysisScopeFingerprint = analysisScopeFingerprint
    }

    public var primary: RenderedAttachmentAnalysis? {
        analysis(for: .primaryColor)
    }

    public var auxiliaries: [RenderedAttachmentAnalysis] {
        analyses.filter { $0.attachment.semantic != .primaryColor }
    }

    public var debugPolicies: [RenderOutputAttachmentDebugPolicy] {
        attachmentSet.debugPolicies
    }

    public func analysis(index: Int) -> RenderedAttachmentAnalysis? {
        analyses.first { $0.attachment.index == index }
    }

    public func analysis(for semantic: RenderOutputAttachmentSemantic) -> RenderedAttachmentAnalysis? {
        analyses.first { $0.attachment.semantic == semantic }
    }
}

public extension RenderedAttachmentSet {
    func makeAnalysis(for semantic: RenderOutputAttachmentSemantic,
                      channel: TextureHistogramChannel? = nil,
                      bins: Int = 256,
                      histogramHeight: Int = 64,
                      scope: TextureAnalysisScope,
                      preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedAttachmentAnalysis? {
        makeAnalysis(
            for: semantic,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            region: scope.region,
            mask: scope.mask,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func makeAnalysis(for semantic: RenderOutputAttachmentSemantic,
                      channel: TextureHistogramChannel? = nil,
                      bins: Int = 256,
                      histogramHeight: Int = 64,
                      region: MTLRegion? = nil,
                      mask: MaskDescriptor? = nil,
                      coverageThreshold: Float = 0.5,
                      preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedAttachmentAnalysis? {
        guard let attachment = attachment(for: semantic) else { return nil }
        let resolvedChannel = channel ?? attachment.defaultHistogramChannel
        let statistics = attachment.makeStatistics(
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold
        )
        let histogramAttachment = attachment.texture.c7.renderHistogramAttachment(
            channel: resolvedChannel,
            bins: bins,
            height: histogramHeight,
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? attachment.makeHistogram(
            channel: resolvedChannel,
            bins: bins,
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
        return RenderedAttachmentAnalysis(
            attachment: attachment,
            histogram: histogram,
            statistics: statistics,
            histogramAttachment: histogramAttachment
        )
    }

    func makeAnalysisBundle(bins: Int = 256,
                            histogramHeight: Int = 64,
                            region: MTLRegion? = nil,
                            mask: MaskDescriptor? = nil,
                            coverageThreshold: Float = 0.5,
                            preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedAttachmentAnalysisBundle {
        let analyses = attachments.compactMap { attachment in
            makeAnalysis(
                for: attachment.semantic,
                channel: nil,
                bins: bins,
                histogramHeight: histogramHeight,
                region: region,
                mask: mask,
                coverageThreshold: coverageThreshold,
                preferredMethod: preferredMethod
            )
        }
        return RenderedAttachmentAnalysisBundle(
            attachmentSet: self,
            analyses: analyses,
            analysisScopeFingerprint: TextureAnalysisScope(
                region: region,
                mask: mask,
                coverageThreshold: coverageThreshold
            ).fingerprint
        )
    }

    func makeAnalysisBundle(bins: Int = 256,
                            histogramHeight: Int = 64,
                            scope: TextureAnalysisScope,
                            preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedAttachmentAnalysisBundle {
        let analyses = attachments.compactMap { attachment in
            makeAnalysis(
                for: attachment.semantic,
                channel: nil,
                bins: bins,
                histogramHeight: histogramHeight,
                scope: scope,
                preferredMethod: preferredMethod
            )
        }
        return RenderedAttachmentAnalysisBundle(
            attachmentSet: self,
            analyses: analyses,
            analysisScopeFingerprint: scope.fingerprint
        )
    }
}

public extension RenderProtocol {
    func renderAttachmentAnalysisBundle(from sourceTexture: MTLTexture,
                                        identifier: String = "RenderAttachmentAnalysisBundle",
                                        bins: Int = 256,
                                        histogramHeight: Int = 64,
                                        region: MTLRegion? = nil,
                                        mask: MaskDescriptor? = nil,
                                        coverageThreshold: Float = 0.5,
                                        preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle {
        try renderAttachmentSet(
            from: sourceTexture,
            identifier: identifier
        ).makeAnalysisBundle(
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func renderAttachmentAnalysisBundle(from sourceTexture: MTLTexture,
                                        identifier: String = "RenderAttachmentAnalysisBundle",
                                        bins: Int = 256,
                                        histogramHeight: Int = 64,
                                        scope: TextureAnalysisScope,
                                        preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle {
        try renderAttachmentAnalysisBundle(
            from: sourceTexture,
            identifier: identifier,
            bins: bins,
            histogramHeight: histogramHeight,
            region: scope.region,
            mask: scope.mask,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }
}

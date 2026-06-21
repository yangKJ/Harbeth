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
    public let histogramAttachment: RenderedHistogramAttachment?

    public init(attachment: RenderedAttachment,
                histogram: TextureHistogram?,
                histogramAttachment: RenderedHistogramAttachment?) {
        self.attachment = attachment
        self.histogram = histogram
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

    public init(attachmentSet: RenderedAttachmentSet,
                analyses: [RenderedAttachmentAnalysis]) {
        self.attachmentSet = attachmentSet
        self.analyses = analyses.sorted { $0.attachment.index < $1.attachment.index }
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
                      region: MTLRegion? = nil,
                      preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedAttachmentAnalysis? {
        guard let attachment = attachment(for: semantic) else { return nil }
        let resolvedChannel = channel ?? attachment.defaultHistogramChannel
        let histogramAttachment = attachment.texture.c7.renderHistogramAttachment(
            channel: resolvedChannel,
            bins: bins,
            height: histogramHeight,
            region: region,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? attachment.makeHistogram(
            channel: resolvedChannel,
            bins: bins,
            region: region,
            preferredMethod: preferredMethod
        )
        return RenderedAttachmentAnalysis(
            attachment: attachment,
            histogram: histogram,
            histogramAttachment: histogramAttachment
        )
    }

    func makeAnalysisBundle(bins: Int = 256,
                            histogramHeight: Int = 64,
                            region: MTLRegion? = nil,
                            preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedAttachmentAnalysisBundle {
        let analyses = attachments.compactMap { attachment in
            makeAnalysis(
                for: attachment.semantic,
                channel: nil,
                bins: bins,
                histogramHeight: histogramHeight,
                region: region,
                preferredMethod: preferredMethod
            )
        }
        return RenderedAttachmentAnalysisBundle(
            attachmentSet: self,
            analyses: analyses
        )
    }
}

public extension RenderProtocol {
    func renderAttachmentAnalysisBundle(from sourceTexture: MTLTexture,
                                        identifier: String = "RenderAttachmentAnalysisBundle",
                                        bins: Int = 256,
                                        histogramHeight: Int = 64,
                                        region: MTLRegion? = nil,
                                        preferredMethod: TextureHistogramComputationMethod = .gpuMPS) throws -> RenderedAttachmentAnalysisBundle {
        try renderAttachmentSet(
            from: sourceTexture,
            identifier: identifier
        ).makeAnalysisBundle(
            bins: bins,
            histogramHeight: histogramHeight,
            region: region,
            preferredMethod: preferredMethod
        )
    }
}

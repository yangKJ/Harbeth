//
//  RenderedAttachmentAnalysisBundle.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import CoreGraphics
import Metal

public struct RenderedAttachmentAnalysisSummary: Sendable, Codable, Equatable, Hashable {
    public let index: Int
    public let semantic: RenderOutputAttachmentSemantic
    public let pixelFormat: String
    public let debugPolicy: RenderOutputAttachmentDebugPolicy
    public let histogramChannel: TextureHistogramChannel?
    public let histogramBinCount: Int
    public let histogramPeakCount: UInt32?
    public let histogramTotalSampleCount: Int?
    public let statisticsSampleCount: Int?
    public let meanRed: Float?
    public let meanGreen: Float?
    public let meanBlue: Float?
    public let meanAlpha: Float?
    public let meanLuminance: Float?
    public let minimumLuminance: Float?
    public let maximumLuminance: Float?
    public let hasHistogramAttachment: Bool

    public init(index: Int,
                semantic: RenderOutputAttachmentSemantic,
                pixelFormat: String,
                debugPolicy: RenderOutputAttachmentDebugPolicy,
                histogramChannel: TextureHistogramChannel?,
                histogramBinCount: Int,
                histogramPeakCount: UInt32?,
                histogramTotalSampleCount: Int?,
                statisticsSampleCount: Int?,
                meanRed: Float?,
                meanGreen: Float?,
                meanBlue: Float?,
                meanAlpha: Float?,
                meanLuminance: Float?,
                minimumLuminance: Float?,
                maximumLuminance: Float?,
                hasHistogramAttachment: Bool) {
        self.index = index
        self.semantic = semantic
        self.pixelFormat = pixelFormat
        self.debugPolicy = debugPolicy
        self.histogramChannel = histogramChannel
        self.histogramBinCount = histogramBinCount
        self.histogramPeakCount = histogramPeakCount
        self.histogramTotalSampleCount = histogramTotalSampleCount
        self.statisticsSampleCount = statisticsSampleCount
        self.meanRed = meanRed
        self.meanGreen = meanGreen
        self.meanBlue = meanBlue
        self.meanAlpha = meanAlpha
        self.meanLuminance = meanLuminance
        self.minimumLuminance = minimumLuminance
        self.maximumLuminance = maximumLuminance
        self.hasHistogramAttachment = hasHistogramAttachment
    }

    public var fingerprint: String {
        [
            "attachment=\(index)",
            "semantic=\(semantic.rawValue)",
            "pixel=\(pixelFormat)",
            "debug=\(debugPolicy.label)",
            "histogramChannel=\(histogramChannel?.rawValue ?? "none")",
            "histogramBins=\(histogramBinCount)",
            "histogramSamples=\(histogramTotalSampleCount.map(String.init) ?? "none")",
            "statisticsSamples=\(statisticsSampleCount.map(String.init) ?? "none")",
            "histogramAttachment=\(hasHistogramAttachment ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public struct RenderedAttachmentAnalysisBundleSummary: Sendable, Codable, Equatable, Hashable {
    public let outputContractFingerprint: String
    public let analysisScopeFingerprint: String?
    public let attachmentLabels: [String]
    public let analyses: [RenderedAttachmentAnalysisSummary]

    public init(outputContractFingerprint: String,
                analysisScopeFingerprint: String?,
                attachmentLabels: [String],
                analyses: [RenderedAttachmentAnalysisSummary]) {
        self.outputContractFingerprint = outputContractFingerprint
        self.analysisScopeFingerprint = analysisScopeFingerprint
        self.attachmentLabels = attachmentLabels
        self.analyses = analyses.sorted { $0.index < $1.index }
    }

    public var fingerprint: String {
        [
            "outputContract=\(outputContractFingerprint)",
            "scope=\(analysisScopeFingerprint ?? "none")",
            "labels=\(attachmentLabels.joined(separator: ","))",
            "analyses=\(analyses.map(\.fingerprint).joined(separator: "||"))"
        ].joined(separator: "|")
    }

    public func jsonData(prettyPrinted: Bool = false,
                         sortedKeys: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting.insert(.prettyPrinted)
        }
        if sortedKeys {
            encoder.outputFormatting.insert(.sortedKeys)
        }
        return try encoder.encode(self)
    }

    public func jsonString(prettyPrinted: Bool = false,
                           sortedKeys: Bool = true) throws -> String {
        let data = try jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
        guard let string = String(data: data, encoding: .utf8) else {
            throw HarbethError.configurationInvalid("RenderedAttachmentAnalysisBundleSummary JSON encoding is not valid UTF-8.")
        }
        return string
    }
}

/// 单个 attachment 的稳定分析结果。
public struct RenderedAttachmentAnalysis: @unchecked Sendable {
    public let attachment: RenderedAttachment
    public let histogram: TextureHistogram?
    public let statistics: TextureStatistics?
    public let colorProbe: TextureColorProbe?
    public let histogramAttachment: RenderedHistogramAttachment?

    public init(attachment: RenderedAttachment,
                histogram: TextureHistogram?,
                statistics: TextureStatistics?,
                colorProbe: TextureColorProbe?,
                histogramAttachment: RenderedHistogramAttachment?) {
        self.attachment = attachment
        self.histogram = histogram
        self.statistics = statistics
        self.colorProbe = colorProbe
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

    public var summary: RenderedAttachmentAnalysisSummary {
        RenderedAttachmentAnalysisSummary(
            index: attachment.index,
            semantic: attachment.semantic,
            pixelFormat: String(describing: attachment.pixelFormat),
            debugPolicy: attachment.debugPolicy,
            histogramChannel: histogram?.channel,
            histogramBinCount: histogram?.binCount ?? 0,
            histogramPeakCount: histogram?.peakCount,
            histogramTotalSampleCount: histogram?.totalSampleCount,
            statisticsSampleCount: statistics?.sampleCount,
            meanRed: statistics?.meanRed,
            meanGreen: statistics?.meanGreen,
            meanBlue: statistics?.meanBlue,
            meanAlpha: statistics?.meanAlpha,
            meanLuminance: statistics?.meanLuminance,
            minimumLuminance: statistics?.minimumLuminance,
            maximumLuminance: statistics?.maximumLuminance,
            hasHistogramAttachment: histogramAttachment != nil
        )
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

    public var summary: RenderedAttachmentAnalysisBundleSummary {
        RenderedAttachmentAnalysisBundleSummary(
            outputContractFingerprint: attachmentSet.outputContract.fingerprint,
            analysisScopeFingerprint: analysisScopeFingerprint,
            attachmentLabels: debugPolicies.map(\.label),
            analyses: analyses.map(\.summary)
        )
    }

    public func jsonData(prettyPrinted: Bool = false,
                         sortedKeys: Bool = true) throws -> Data {
        try summary.jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func jsonString(prettyPrinted: Bool = false,
                           sortedKeys: Bool = true) throws -> String {
        try summary.jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
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
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
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
                      luminanceRange: TextureLuminanceRange? = nil,
                      colorRange: TextureColorRange? = nil,
                      coverageThreshold: Float = 0.5,
                      preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedAttachmentAnalysis? {
        guard let attachment = attachment(for: semantic) else { return nil }
        let resolvedChannel = channel ?? attachment.defaultHistogramChannel
        let statistics = attachment.makeStatistics(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
        let colorProbe = attachment.makeColorProbe(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
        let histogramAttachment = attachment.texture.c7.renderHistogramAttachment(
            channel: resolvedChannel,
            bins: bins,
            height: histogramHeight,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
        let histogram = histogramAttachment?.histogram ?? attachment.makeHistogram(
            channel: resolvedChannel,
            bins: bins,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
        return RenderedAttachmentAnalysis(
            attachment: attachment,
            histogram: histogram,
            statistics: statistics,
            colorProbe: colorProbe,
            histogramAttachment: histogramAttachment
        )
    }

    func makeAnalysisBundle(bins: Int = 256,
                            histogramHeight: Int = 64,
                            region: MTLRegion? = nil,
                            mask: MaskDescriptor? = nil,
                            luminanceRange: TextureLuminanceRange? = nil,
                            colorRange: TextureColorRange? = nil,
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
                luminanceRange: luminanceRange,
                colorRange: colorRange,
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
                luminanceRange: luminanceRange,
                colorRange: colorRange,
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
                                        luminanceRange: TextureLuminanceRange? = nil,
                                        colorRange: TextureColorRange? = nil,
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
            luminanceRange: luminanceRange,
            colorRange: colorRange,
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
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }
}

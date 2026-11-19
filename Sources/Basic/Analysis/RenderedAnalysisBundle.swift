//
//  RenderedAnalysisBundle.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import CoreGraphics
import Metal

/// 轻量分析输出集合。
///
/// 目标是让上层一次拿到稳定 frame、histogram 数据和 histogram preview，
/// 不需要自己重复装配 texture/frame/readback 细节。
public struct RenderedAnalysisBundle: @unchecked Sendable {
    public let frame: RenderedFrame
    public let histogram: TextureHistogram?
    public let statistics: TextureStatistics?
    public let colorProbe: TextureColorProbe?
    public let histogramAttachment: RenderedHistogramAttachment?
    public let analysisScopeFingerprint: String?
    public let attachmentDebugPolicies: [RenderOutputAttachmentDebugPolicy]

    init(frame: RenderedFrame,
         histogram: TextureHistogram?,
         statistics: TextureStatistics?,
         colorProbe: TextureColorProbe?,
         histogramAttachment: RenderedHistogramAttachment?,
         analysisScopeFingerprint: String? = nil,
         attachmentDebugPolicies: [RenderOutputAttachmentDebugPolicy]) {
        self.frame = frame
        self.histogram = histogram
        self.statistics = statistics
        self.colorProbe = colorProbe
        self.histogramAttachment = histogramAttachment
        self.analysisScopeFingerprint = analysisScopeFingerprint
        self.attachmentDebugPolicies = attachmentDebugPolicies
    }

    public var primaryDebugPolicy: RenderOutputAttachmentDebugPolicy? {
        attachmentDebugPolicies.first
    }

    public func makePrimaryCGImage() -> CGImage? {
        frame.texture.c7.toCGImage(
            colorSpace: frame.colorSpace,
            alphaType: frame.alphaType
        )
    }

    public func makeHistogramCGImage() -> CGImage? {
        histogramAttachment?.makeCGImage(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            alphaType: .premultiplied
        )
    }
}

extension RenderedAnalysisBundle {
    static func makeRegionBundle(
        frame: RenderedFrame,
        channel: TextureHistogramChannel,
        bins: Int,
        histogramHeight: Int,
        region: MTLRegion?,
        preferredMethod: TextureHistogramComputationMethod,
        attachmentDebugPolicies: [RenderOutputAttachmentDebugPolicy]
    ) -> RenderedAnalysisBundle {
        makeBundle(
            frame: frame,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            scope: TextureAnalysisScope(region: region),
            preferredMethod: preferredMethod,
            attachmentDebugPolicies: attachmentDebugPolicies
        )
    }

    static func makeScopeBundle(
        frame: RenderedFrame,
        channel: TextureHistogramChannel,
        bins: Int,
        histogramHeight: Int,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod,
        attachmentDebugPolicies: [RenderOutputAttachmentDebugPolicy]
    ) -> RenderedAnalysisBundle {
        makeBundle(
            frame: frame,
            channel: channel,
            bins: bins,
            histogramHeight: histogramHeight,
            scope: scope,
            preferredMethod: preferredMethod,
            attachmentDebugPolicies: attachmentDebugPolicies
        )
    }

    private static func makeBundle(
        frame: RenderedFrame,
        channel: TextureHistogramChannel,
        bins: Int,
        histogramHeight: Int,
        scope: TextureAnalysisScope,
        preferredMethod: TextureHistogramComputationMethod,
        attachmentDebugPolicies: [RenderOutputAttachmentDebugPolicy]
    ) -> RenderedAnalysisBundle {
        let artifacts = TextureAnalysisArtifacts.make(
            texture: frame.texture, channel: channel, bins: bins,
            height: histogramHeight, scope: scope,
            preferredMethod: preferredMethod
        )
        let statistics = artifacts.statistics
        let colorProbe = frame.texture.c7.resolvedHistogramRegion(scope.region).flatMap { region in
            statistics.map { TextureColorProbe(region: region, statistics: $0) }
        }
        return RenderedAnalysisBundle(
            frame: frame,
            histogram: artifacts.histogram,
            statistics: statistics,
            colorProbe: colorProbe,
            histogramAttachment: artifacts.histogramAttachment,
            analysisScopeFingerprint: scope.fingerprint,
            attachmentDebugPolicies: attachmentDebugPolicies
        )
    }
}

extension TextureAnalysisArtifacts {
    /// GPU 一次提交；需要回退时共享一次 ROI 读回和一次 mask 解析。
    static func make(texture: MTLTexture, channel: TextureHistogramChannel, bins: Int, height: Int,
                     scope: TextureAnalysisScope, preferredMethod: TextureHistogramComputationMethod) -> Self {
        let compatible = texture.c7
        let empty = compatible.resolvedHistogramRegion(scope.region) == nil
        let gpu = preferredMethod == .gpuMPS && !empty
            ? GPUTextureAnalysis.bundle(texture, channel: channel, bins: max(1, bins), height: height, scope: scope) : nil
        if let gpu, gpu.statistics != nil, gpu.histogram != nil, gpu.histogramAttachment != nil { return gpu }
        let readback = TextureAnalysisReadback(texture: texture, region: scope.region)
        let mask = readback == nil ? nil : compatible.makeMaskCoverageSample(for: scope.mask)
        let statistics = gpu?.statistics ?? readback.flatMap {
            compatible.makeStatistics(
                readback: $0, region: scope.region,
                maskSample: mask,
                luminanceRange: scope.luminanceRange,
                colorRange: scope.colorRange,
                coverageThreshold: scope.coverageThreshold
            )
        } ?? (empty ? compatible.makeStatistics(scope: scope) : nil)
        let histogram = gpu?.histogram ?? readback.flatMap {
            compatible.makeCPUHistogram(
                readback: $0, maskSample: mask,
                channel: channel, bins: bins,
                region: scope.region,
                luminanceRange: scope.luminanceRange,
                colorRange: scope.colorRange,
                coverageThreshold: scope.coverageThreshold,
                valueRange: scope.valueRange
            )
        } ?? (empty ? compatible.makeHistogram(channel: channel, bins: bins, scope: scope, preferredMethod: .cpuReadback) : nil)
        let preview = gpu?.histogramAttachment ?? histogram.flatMap {
            compatible.makeHistogramAttachment(from: $0, height: height)
        }
        return Self(statistics: statistics, histogram: histogram, histogramAttachment: preview)
    }
}

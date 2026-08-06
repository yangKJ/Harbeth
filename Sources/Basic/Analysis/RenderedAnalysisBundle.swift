//
//  RenderedAnalysisBundle.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import CoreGraphics

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
    /// 区域维度 analysis bundle 工厂：用于 `RenderRequest.renderAnalysisBundle(channel:bins:histogramHeight:region:preferredMethod:)` 闭包。
    ///
    /// 行为契约（与原 ImageNode / EditRecipe / LayerCompositeRecipe 内联实现一致）：
    /// - `analysisScopeFingerprint` 用 `TextureAnalysisScope(region: region).fingerprint` 包装
    /// - `histogram` 优先用 `histogramAttachment?.histogram`，否则用 `frame.makeHistogram(region:)`
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

    /// 作用域维度 analysis bundle 工厂：用于 `RenderRequest.renderAnalysisBundle(channel:bins:histogramHeight:scope:preferredMethod:)` 闭包。
    ///
    /// 行为契约（与原 ImageNode / EditRecipe / LayerCompositeRecipe 内联实现一致）：
    /// - `analysisScopeFingerprint` 直接用 `scope.fingerprint`
    /// - `histogram` 优先用 `histogramAttachment?.histogram`，否则用 `frame.makeHistogram(scope:)`
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
        let texture = frame.texture.c7
        let requiresCPUHistogram = preferredMethod == .cpuReadback || scope.mask != nil || scope.luminanceRange != nil || scope.colorRange != nil
        let readback = TextureAnalysisReadback(texture: frame.texture)
        let maskSample = texture.makeMaskCoverageSample(for: scope.mask)

        let statistics = readback.flatMap {
            texture.makeStatistics(
                readback: $0,
                region: scope.region,
                maskSample: maskSample,
                luminanceRange: scope.luminanceRange,
                colorRange: scope.colorRange,
                coverageThreshold: scope.coverageThreshold
            )
        }
        let colorProbe = texture.resolvedHistogramRegion(scope.region).flatMap { resolvedRegion in
            statistics.map { TextureColorProbe(region: resolvedRegion, statistics: $0) }
        }

        let histogram: TextureHistogram?
        let histogramAttachment: RenderedHistogramAttachment?
        if requiresCPUHistogram, let readback {
            histogram = texture.makeCPUHistogram(
                readback: readback,
                maskSample: maskSample,
                channel: channel,
                bins: bins,
                region: scope.region,
                luminanceRange: scope.luminanceRange,
                colorRange: scope.colorRange,
                coverageThreshold: scope.coverageThreshold,
                valueRange: scope.valueRange
            )
            histogramAttachment = histogram.flatMap { histogram in
                texture.makePreviewTexture(from: histogram, height: histogramHeight).map { previewTexture in
                    RenderedHistogramAttachment(
                        histogram: histogram,
                        attachment: RenderedAttachment(
                            index: 1,
                            semantic: .histogram,
                            texture: previewTexture,
                            debugPolicy: RenderOutputAttachmentContract.histogram(index: 1, pixelFormat: .rgba8Unorm).debugPolicy
                        )
                    )
                }
            }
        } else {
            histogramAttachment = frame.renderHistogramAttachment(
                channel: channel,
                bins: bins,
                height: histogramHeight,
                scope: scope,
                preferredMethod: preferredMethod
            )
            histogram = histogramAttachment?.histogram ?? frame.makeHistogram(
                channel: channel,
                bins: bins,
                scope: scope,
                preferredMethod: preferredMethod
            )
        }

        return RenderedAnalysisBundle(
            frame: frame,
            histogram: histogram,
            statistics: statistics,
            colorProbe: colorProbe,
            histogramAttachment: histogramAttachment,
            analysisScopeFingerprint: scope.fingerprint,
            attachmentDebugPolicies: attachmentDebugPolicies
        )
    }
}

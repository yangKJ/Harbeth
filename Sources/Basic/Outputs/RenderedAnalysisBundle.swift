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

    public init(frame: RenderedFrame,
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

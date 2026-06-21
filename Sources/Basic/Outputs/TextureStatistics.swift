//
//  TextureStatistics.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal

public struct TextureStatistics: Sendable, Equatable {
    public let sampleCount: Int
    public let meanRed: Float
    public let meanGreen: Float
    public let meanBlue: Float
    public let meanAlpha: Float
    public let meanLuminance: Float
    public let minimumLuminance: Float
    public let maximumLuminance: Float

    public init(sampleCount: Int,
                meanRed: Float,
                meanGreen: Float,
                meanBlue: Float,
                meanAlpha: Float,
                meanLuminance: Float,
                minimumLuminance: Float,
                maximumLuminance: Float) {
        self.sampleCount = max(sampleCount, 0)
        self.meanRed = meanRed
        self.meanGreen = meanGreen
        self.meanBlue = meanBlue
        self.meanAlpha = meanAlpha
        self.meanLuminance = meanLuminance
        self.minimumLuminance = minimumLuminance
        self.maximumLuminance = maximumLuminance
    }

    public var isEmpty: Bool {
        sampleCount == 0
    }
}

public extension MTLTextureCompatible_ {
    func makeStatistics(scope: TextureAnalysisScope) -> TextureStatistics? {
        makeStatistics(
            region: scope.region,
            mask: scope.mask,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeStatistics(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        coverageThreshold: Float = 0.5) -> TextureStatistics? {
        guard let bytes = bytes() else { return nil }
        let width = target.width
        let height = target.height
        guard let resolvedRegion = resolvedHistogramRegion(region),
              width > 0,
              height > 0 else {
            return TextureStatistics(
                sampleCount: 0,
                meanRed: 0,
                meanGreen: 0,
                meanBlue: 0,
                meanAlpha: 0,
                meanLuminance: 0,
                minimumLuminance: 0,
                maximumLuminance: 0
            )
        }

        let resolvedCoverageThreshold = min(max(coverageThreshold, 0), 1)
        let maskSample = makeMaskCoverageSample(for: mask)
        let bytesPerRow = width * 4

        var sampleCount = 0
        var redSum: Float = 0
        var greenSum: Float = 0
        var blueSum: Float = 0
        var alphaSum: Float = 0
        var luminanceSum: Float = 0
        var minimumLuminance: Float = 1
        var maximumLuminance: Float = 0

        bytes.withUnsafeBytes { rawBuffer in
            let rgba = rawBuffer.bindMemory(to: UInt8.self)
            for y in resolvedRegion.origin.y..<(resolvedRegion.origin.y + resolvedRegion.size.height) {
                let rowBase = y * bytesPerRow
                for x in resolvedRegion.origin.x..<(resolvedRegion.origin.x + resolvedRegion.size.width) {
                    if let maskSample,
                       maskSample.coverage(atSourceX: x, y: y, sourceWidth: width, sourceHeight: height) < resolvedCoverageThreshold {
                        continue
                    }
                    let offset = rowBase + x * 4
                    let red = Float(rgba[offset]) / 255.0
                    let green = Float(rgba[offset + 1]) / 255.0
                    let blue = Float(rgba[offset + 2]) / 255.0
                    let alpha = Float(rgba[offset + 3]) / 255.0
                    let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722

                    redSum += red
                    greenSum += green
                    blueSum += blue
                    alphaSum += alpha
                    luminanceSum += luminance
                    minimumLuminance = min(minimumLuminance, luminance)
                    maximumLuminance = max(maximumLuminance, luminance)
                    sampleCount += 1
                }
            }
        }

        guard sampleCount > 0 else {
            return TextureStatistics(
                sampleCount: 0,
                meanRed: 0,
                meanGreen: 0,
                meanBlue: 0,
                meanAlpha: 0,
                meanLuminance: 0,
                minimumLuminance: 0,
                maximumLuminance: 0
            )
        }

        let divisor = Float(sampleCount)
        return TextureStatistics(
            sampleCount: sampleCount,
            meanRed: redSum / divisor,
            meanGreen: greenSum / divisor,
            meanBlue: blueSum / divisor,
            meanAlpha: alphaSum / divisor,
            meanLuminance: luminanceSum / divisor,
            minimumLuminance: minimumLuminance,
            maximumLuminance: maximumLuminance
        )
    }
}

public extension RenderedAttachment {
    func makeStatistics(scope: TextureAnalysisScope) -> TextureStatistics? {
        makeStatistics(
            region: scope.region,
            mask: scope.mask,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeStatistics(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        coverageThreshold: Float = 0.5) -> TextureStatistics? {
        texture.c7.makeStatistics(
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold
        )
    }
}

public extension RenderedAttachmentSet {
    func makeStatistics(for semantic: RenderOutputAttachmentSemantic,
                        scope: TextureAnalysisScope) -> TextureStatistics? {
        makeStatistics(
            for: semantic,
            region: scope.region,
            mask: scope.mask,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeStatistics(for semantic: RenderOutputAttachmentSemantic,
                        region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        coverageThreshold: Float = 0.5) -> TextureStatistics? {
        attachment(for: semantic)?.makeStatistics(
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold
        )
    }
}

public extension RenderedFrame {
    func makeStatistics(scope: TextureAnalysisScope) -> TextureStatistics? {
        makeStatistics(
            region: scope.region,
            mask: scope.mask,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeStatistics(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        coverageThreshold: Float = 0.5) -> TextureStatistics? {
        texture.c7.makeStatistics(
            region: region,
            mask: mask,
            coverageThreshold: coverageThreshold
        )
    }
}

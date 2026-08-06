//
//  TextureStatistics.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal

public struct TextureStatistics: Sendable, Equatable {
    public let pixelFormat: PixelFormatContract
    public let componentDomain: TextureAnalysisComponentDomain
    public let sampleCount: Int
    public let meanRed: Float
    public let meanGreen: Float
    public let meanBlue: Float
    public let meanAlpha: Float
    public let meanLuminance: Float
    public let minimumLuminance: Float
    public let maximumLuminance: Float

    init(pixelFormat: PixelFormatContract,
         componentDomain: TextureAnalysisComponentDomain = .textureStorage,
         sampleCount: Int,
         meanRed: Float,
         meanGreen: Float,
         meanBlue: Float,
         meanAlpha: Float,
         meanLuminance: Float,
         minimumLuminance: Float,
         maximumLuminance: Float) {
        self.pixelFormat = pixelFormat
        self.componentDomain = componentDomain
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
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeStatistics(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureStatistics? {
        guard let readback = TextureAnalysisReadback(texture: target) else { return nil }
        return makeStatistics(
            readback: readback,
            region: region,
            maskSample: makeMaskCoverageSample(for: mask),
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    internal func makeStatistics(readback: TextureAnalysisReadback,
                                 region: MTLRegion?,
                                 maskSample: MaskCoverageSample?,
                                 luminanceRange: TextureLuminanceRange?,
                                 colorRange: TextureColorRange?,
                                 coverageThreshold: Float) -> TextureStatistics? {
        let width = target.width
        let height = target.height
        guard let resolvedRegion = resolvedHistogramRegion(region), width > 0, height > 0 else {
            return TextureStatistics(
                pixelFormat: PixelFormatContract(pixelFormat: target.pixelFormat, preservesInput: false),
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
        var sampleCount = 0
        var redSum: Float = 0
        var greenSum: Float = 0
        var blueSum: Float = 0
        var alphaSum: Float = 0
        var luminanceSum: Float = 0
        var minimumLuminance = Float.greatestFiniteMagnitude
        var maximumLuminance = -Float.greatestFiniteMagnitude

        for y in resolvedRegion.origin.y..<(resolvedRegion.origin.y + resolvedRegion.size.height) {
            for x in resolvedRegion.origin.x..<(resolvedRegion.origin.x + resolvedRegion.size.width) {
                if let maskSample,
                   maskSample.coverage(atSourceX: x, y: y, sourceWidth: width, sourceHeight: height) < resolvedCoverageThreshold {
                    continue
                }
                guard let color = readback.color(x: x, y: y) else { continue }
                let red = color.x
                let green = color.y
                let blue = color.z
                let alpha = color.w
                let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
                if let luminanceRange, luminanceRange.contains(luminance) == false {
                    continue
                }
                if let colorRange, colorRange.contains(red: red, green: green, blue: blue) == false {
                    continue
                }

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

        guard sampleCount > 0 else {
            return TextureStatistics(
                pixelFormat: PixelFormatContract(pixelFormat: target.pixelFormat, preservesInput: false),
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
            pixelFormat: PixelFormatContract(pixelFormat: target.pixelFormat, preservesInput: false),
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
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeStatistics(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureStatistics? {
        texture.c7.makeStatistics(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }
}

public extension RenderedAttachmentSet {
    func makeStatistics(for semantic: RenderOutputAttachmentSemantic, scope: TextureAnalysisScope) -> TextureStatistics? {
        makeStatistics(
            for: semantic,
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeStatistics(for semantic: RenderOutputAttachmentSemantic,
                        region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureStatistics? {
        attachment(for: semantic)?.makeStatistics(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }
}

public extension RenderedFrame {
    func makeStatistics(scope: TextureAnalysisScope) -> TextureStatistics? {
        makeStatistics(
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeStatistics(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureStatistics? {
        texture.c7.makeStatistics(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }
}

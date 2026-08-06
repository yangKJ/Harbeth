//
//  TextureColorProbe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import Metal

public struct TextureColorProbe: Sendable {
    public let pixelFormat: PixelFormatContract
    public let componentDomain: TextureAnalysisComponentDomain
    public let region: MTLRegion
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
         region: MTLRegion,
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
        self.region = region
        self.sampleCount = max(sampleCount, 0)
        self.meanRed = meanRed
        self.meanGreen = meanGreen
        self.meanBlue = meanBlue
        self.meanAlpha = meanAlpha
        self.meanLuminance = meanLuminance
        self.minimumLuminance = minimumLuminance
        self.maximumLuminance = maximumLuminance
    }

    init(region: MTLRegion, statistics: TextureStatistics) {
        self.init(
            pixelFormat: statistics.pixelFormat,
            componentDomain: statistics.componentDomain,
            region: region,
            sampleCount: statistics.sampleCount,
            meanRed: statistics.meanRed,
            meanGreen: statistics.meanGreen,
            meanBlue: statistics.meanBlue,
            meanAlpha: statistics.meanAlpha,
            meanLuminance: statistics.meanLuminance,
            minimumLuminance: statistics.minimumLuminance,
            maximumLuminance: statistics.maximumLuminance
        )
    }

    public var meanColor: SIMD4<Float> {
        SIMD4(meanRed, meanGreen, meanBlue, meanAlpha)
    }

    public var meanColor8: SIMD4<UInt8> {
        SIMD4(
            UInt8(clamping: Int((meanRed * 255).rounded())),
            UInt8(clamping: Int((meanGreen * 255).rounded())),
            UInt8(clamping: Int((meanBlue * 255).rounded())),
            UInt8(clamping: Int((meanAlpha * 255).rounded()))
        )
    }

    public var regionFingerprint: String {
        [
            String(region.origin.x),
            String(region.origin.y),
            String(region.origin.z),
            String(region.size.width),
            String(region.size.height),
            String(region.size.depth)
        ].joined(separator: ",")
    }
}

public extension TextureAnalysisScope {
    static func point(x: Int,
                      y: Int,
                      radius: Int = 0,
                      mask: MaskDescriptor? = nil,
                      luminanceRange: TextureLuminanceRange? = nil,
                      colorRange: TextureColorRange? = nil,
                      coverageThreshold: Float = 0.5,
                      valueRange: TextureAnalysisValueRange = .normalized) -> TextureAnalysisScope {
        let diameter = max(radius, 0) * 2 + 1
        return TextureAnalysisScope(
            region: MTLRegionMake2D(
                max(x - max(radius, 0), 0),
                max(y - max(radius, 0), 0),
                diameter,
                diameter
            ),
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            valueRange: valueRange
        )
    }
}

public extension MTLTextureCompatible_ {
    func makeColorProbe(scope: TextureAnalysisScope) -> TextureColorProbe? {
        makeColorProbe(
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold
        )
    }

    func makeColorProbe(x: Int,
                        y: Int,
                        radius: Int = 0,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureColorProbe? {
        makeColorProbe(
            region: MTLRegionMake2D(
                max(x - max(radius, 0), 0),
                max(y - max(radius, 0), 0),
                max(radius, 0) * 2 + 1,
                max(radius, 0) * 2 + 1
            ),
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    func makeColorProbe(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureColorProbe? {
        guard let resolvedRegion = resolvedHistogramRegion(region),
              let statistics = makeStatistics(
                region: resolvedRegion,
                mask: mask,
                luminanceRange: luminanceRange,
                colorRange: colorRange,
                coverageThreshold: coverageThreshold
              ) else {
            return nil
        }
        return TextureColorProbe(region: resolvedRegion, statistics: statistics)
    }
}

public extension RenderedAttachment {
    func makeColorProbe(scope: TextureAnalysisScope) -> TextureColorProbe? {
        texture.c7.makeColorProbe(scope: scope)
    }

    func makeColorProbe(x: Int,
                        y: Int,
                        radius: Int = 0,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureColorProbe? {
        texture.c7.makeColorProbe(
            x: x,
            y: y,
            radius: radius,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    func makeColorProbe(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureColorProbe? {
        texture.c7.makeColorProbe(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }
}

public extension RenderedAttachmentSet {
    func makeColorProbe(for semantic: RenderOutputAttachmentSemantic, scope: TextureAnalysisScope) -> TextureColorProbe? {
        attachment(for: semantic)?.makeColorProbe(scope: scope)
    }

    func makeColorProbe(for semantic: RenderOutputAttachmentSemantic,
                        x: Int,
                        y: Int,
                        radius: Int = 0,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureColorProbe? {
        attachment(for: semantic)?.makeColorProbe(
            x: x,
            y: y,
            radius: radius,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    func makeColorProbe(for semantic: RenderOutputAttachmentSemantic,
                        region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureColorProbe? {
        attachment(for: semantic)?.makeColorProbe(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }
}

public extension RenderedFrame {
    func makeColorProbe(scope: TextureAnalysisScope) -> TextureColorProbe? {
        texture.c7.makeColorProbe(scope: scope)
    }

    func makeColorProbe(x: Int,
                        y: Int,
                        radius: Int = 0,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureColorProbe? {
        texture.c7.makeColorProbe(
            x: x,
            y: y,
            radius: radius,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }

    func makeColorProbe(region: MTLRegion? = nil,
                        mask: MaskDescriptor? = nil,
                        luminanceRange: TextureLuminanceRange? = nil,
                        colorRange: TextureColorRange? = nil,
                        coverageThreshold: Float = 0.5) -> TextureColorProbe? {
        texture.c7.makeColorProbe(
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold
        )
    }
}

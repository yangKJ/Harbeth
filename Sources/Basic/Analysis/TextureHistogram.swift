//
//  TextureHistogram.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import CoreGraphics
import Metal

public enum TextureHistogramChannel: String, Sendable, Codable, Equatable, Hashable {
    case luminance
    case red
    case green
    case blue
    case alpha
}

public enum TextureHistogramComputationMethod: String, Sendable, Codable, Equatable, Hashable {
    case cpuReadback
    case gpuMPS
}

public struct TextureHistogram: Sendable, Equatable {
    public let channel: TextureHistogramChannel
    public let bins: [UInt32]
    public let totalSampleCount: Int

    init(channel: TextureHistogramChannel, bins: [UInt32], totalSampleCount: Int) {
        self.channel = channel
        self.bins = bins
        self.totalSampleCount = max(totalSampleCount, 0)
    }

    public var binCount: Int {
        bins.count
    }

    public var peakCount: UInt32 {
        bins.max() ?? 0
    }

    public var normalizedBins: [Float] {
        let peak = max(Float(peakCount), 1)
        return bins.map { Float($0) / peak }
    }

    public func makePreviewCGImage(height: Int = 64) -> CGImage? {
        let width = max(binCount, 1)
        let clampedHeight = max(height, 1)
        let normalized = normalizedBins
        let color: (UInt8, UInt8, UInt8) = {
            switch channel {
            case .red: return (255, 64, 64)
            case .green: return (64, 255, 64)
            case .blue: return (64, 160, 255)
            case .alpha: return (220, 220, 220)
            case .luminance: return (255, 255, 255)
            }
        }()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: clampedHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.setAllowsAntialiasing(false)
        context.setShouldAntialias(false)
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: clampedHeight))

        guard let fillColor = CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [
                CGFloat(color.0) / 255.0,
                CGFloat(color.1) / 255.0,
                CGFloat(color.2) / 255.0,
                1.0
            ]
        ) else {
            return nil
        }
        context.setFillColor(fillColor)
        for (x, value) in normalized.enumerated() {
            let filledHeight = Int((value * Float(clampedHeight)).rounded(.up))
            guard filledHeight > 0 else { continue }
            context.fill(CGRect(
                x: x,
                y: 0,
                width: 1,
                height: min(filledHeight, clampedHeight)
            ))
        }
        return context.makeImage()
    }
}

public struct RenderedHistogramAttachment: @unchecked Sendable {
    public let histogram: TextureHistogram
    public let attachment: RenderedAttachment

    init(histogram: TextureHistogram,
         attachment: RenderedAttachment) {
        self.histogram = histogram
        self.attachment = attachment
    }

    public func makeCGImage(colorSpace: CGColorSpace? = nil, alphaType: AlphaType = .premultiplied) -> CGImage? {
        attachment.makeCGImage(colorSpace: colorSpace, alphaType: alphaType)
    }
}

public extension MTLTextureCompatible_ {
    func makeHistogram(channel: TextureHistogramChannel = .luminance,
                       bins: Int = 256,
                       scope: TextureAnalysisScope,
                       preferredMethod: TextureHistogramComputationMethod = .cpuReadback) -> TextureHistogram? {
        makeHistogram(
            channel: channel,
            bins: bins,
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func makeHistogram(channel: TextureHistogramChannel = .luminance,
                       bins: Int = 256,
                       region: MTLRegion? = nil,
                       mask: MaskDescriptor? = nil,
                       luminanceRange: TextureLuminanceRange? = nil,
                       colorRange: TextureColorRange? = nil,
                       coverageThreshold: Float = 0.5,
                       preferredMethod: TextureHistogramComputationMethod = .cpuReadback) -> TextureHistogram? {
        if mask != nil || luminanceRange != nil || colorRange != nil {
            return makeCPUHistogram(
                channel: channel,
                bins: bins,
                region: region,
                mask: mask,
                luminanceRange: luminanceRange,
                colorRange: colorRange,
                coverageThreshold: coverageThreshold
            )
        }
        switch preferredMethod {
        case .cpuReadback:
            return makeCPUHistogram(
                channel: channel,
                bins: bins,
                region: region,
                mask: mask,
                luminanceRange: luminanceRange,
                colorRange: colorRange,
                coverageThreshold: coverageThreshold
            )
        case .gpuMPS:
            return makeGPUHistogram(channel: channel, bins: bins, region: region) ?? makeCPUHistogram(
                channel: channel,
                bins: bins,
                region: region,
                mask: mask,
                luminanceRange: luminanceRange,
                colorRange: colorRange,
                coverageThreshold: coverageThreshold
            )
        }
    }

    func makeGPUHistogram(channel: TextureHistogramChannel = .luminance, bins: Int = 256, region: MTLRegion? = nil) -> TextureHistogram? {
        GPUHistogramSupport.makeHistogram(from: target, channel: channel, bins: bins, region: region)
    }

    func renderHistogramAttachment(channel: TextureHistogramChannel = .luminance,
                                   bins: Int = 256,
                                   height: Int = 64,
                                   region: MTLRegion? = nil,
                                   mask: MaskDescriptor? = nil,
                                   luminanceRange: TextureLuminanceRange? = nil,
                                   colorRange: TextureColorRange? = nil,
                                   coverageThreshold: Float = 0.5,
                                   preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedHistogramAttachment? {
        if mask == nil && luminanceRange == nil && colorRange == nil {
            switch preferredMethod {
            case .gpuMPS:
                if let output = GPUHistogramSupport.makeRenderedHistogramAttachment(
                    from: target,
                    channel: channel,
                    bins: bins,
                    height: height,
                    region: region
                ) {
                    return output
                }
            case .cpuReadback:
                break
            }
        }
        guard let histogram = makeCPUHistogram(
                channel: channel,
                bins: bins,
                region: region,
                mask: mask,
                luminanceRange: luminanceRange,
                colorRange: colorRange,
                coverageThreshold: coverageThreshold
              ),
              let previewTexture = makePreviewTexture(from: histogram, height: height) else {
            return nil
        }
        return RenderedHistogramAttachment(
            histogram: histogram,
            attachment: RenderedAttachment(
                index: 1,
                semantic: .histogram,
                texture: previewTexture,
                debugPolicy: RenderOutputAttachmentContract.histogram(index: 1, pixelFormat: .rgba8Unorm).debugPolicy
            )
        )
    }

    func renderHistogramAttachment(channel: TextureHistogramChannel = .luminance,
                                   bins: Int = 256,
                                   height: Int = 64,
                                   scope: TextureAnalysisScope,
                                   preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedHistogramAttachment? {
        renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    private func makeCPUHistogram(channel: TextureHistogramChannel,
                                  bins: Int,
                                  region: MTLRegion?,
                                  mask: MaskDescriptor?,
                                  luminanceRange: TextureLuminanceRange?,
                                  colorRange: TextureColorRange?,
                                  coverageThreshold: Float) -> TextureHistogram? {
        let clampedBins = max(1, bins)
        guard let bytes = bytes() else { return nil }
        let width = target.width
        let height = target.height
        guard let resolvedRegion = resolvedHistogramRegion(region), width > 0, height > 0 else {
            return TextureHistogram(channel: channel, bins: [UInt32](repeating: 0, count: clampedBins), totalSampleCount: 0)
        }

        var counts = [UInt32](repeating: 0, count: clampedBins)
        let step = 4
        let scale = Float(clampedBins - 1)
        let bytesPerRow = width * step
        let resolvedCoverageThreshold = min(max(coverageThreshold, 0), 1)
        let maskSample = makeMaskCoverageSample(for: mask)
        var totalSampleCount = 0

        bytes.withUnsafeBytes { rawBuffer in
            let rgba = rawBuffer.bindMemory(to: UInt8.self)
            for y in resolvedRegion.origin.y..<(resolvedRegion.origin.y + resolvedRegion.size.height) {
                let rowBase = y * bytesPerRow
                for x in resolvedRegion.origin.x..<(resolvedRegion.origin.x + resolvedRegion.size.width) {
                    if let maskSample,
                       maskSample.coverage(atSourceX: x, y: y, sourceWidth: width, sourceHeight: height) < resolvedCoverageThreshold {
                        continue
                    }
                    let offset = rowBase + x * step
                    let red = Float(rgba[offset]) / 255.0
                    let green = Float(rgba[offset + 1]) / 255.0
                    let blue = Float(rgba[offset + 2]) / 255.0
                    let alpha = Float(rgba[offset + 3]) / 255.0
                    let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
                    if let luminanceRange, luminanceRange.contains(luminance) == false {
                        continue
                    }
                    if let colorRange, colorRange.contains(red: red, green: green, blue: blue) == false {
                        continue
                    }

                    let value: Float
                    switch channel {
                    case .luminance:
                        value = luminance
                    case .red:
                        value = red
                    case .green:
                        value = green
                    case .blue:
                        value = blue
                    case .alpha:
                        value = alpha
                    }
                    let index = min(max(Int((value * scale).rounded()), 0), clampedBins - 1)
                    counts[index] += 1
                    totalSampleCount += 1
                }
            }
        }

        return TextureHistogram(
            channel: channel,
            bins: counts,
            totalSampleCount: totalSampleCount
        )
    }

    private func makePreviewTexture(from histogram: TextureHistogram, height: Int) -> MTLTexture? {
        guard let image = histogram.makePreviewCGImage(height: height) else {
            return nil
        }
        return try? TextureLoader(
            with: image,
            options: [
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .generateMipmaps: false,
                .SRGB: false,
                .textureCPUCacheMode: true
            ]
        ).texture
    }

    internal func resolvedHistogramRegion(_ requestedRegion: MTLRegion?) -> MTLRegion? {
        let fullRegion = MTLRegionMake2D(0, 0, target.width, target.height)
        let region = requestedRegion ?? fullRegion
        let maxX = min(max(region.origin.x, 0), target.width)
        let maxY = min(max(region.origin.y, 0), target.height)
        let remainingWidth = max(target.width - maxX, 0)
        let remainingHeight = max(target.height - maxY, 0)
        let width = min(max(region.size.width, 0), remainingWidth)
        let height = min(max(region.size.height, 0), remainingHeight)
        guard width > 0, height > 0 else {
            return nil
        }
        return MTLRegionMake2D(maxX, maxY, width, height)
    }

    internal func makeMaskCoverageSample(for mask: MaskDescriptor?) -> MaskCoverageSample? {
        guard let mask else { return nil }
        guard let coverageTexture = try? HarbethIO(
            element: mask.texture,
            filter: MaskCoverageExtract(mask: mask)
        ).renderTexture(profile: .readbackQuality),
        let bytes = coverageTexture.c7.bytes() else {
            guard let bytes = mask.texture.c7.bytes() else { return nil }
            return MaskCoverageSample(
                bytes: bytes,
                width: mask.texture.width,
                height: mask.texture.height,
                component: mask.component,
                invert: mask.invert,
                opacity: mask.opacity,
                normalizedCoverage: false
            )
        }
        return MaskCoverageSample(
            bytes: bytes,
            width: coverageTexture.width,
            height: coverageTexture.height,
            component: .red,
            invert: false,
            opacity: 1,
            normalizedCoverage: true
        )
    }
}

struct MaskCoverageSample {
    let bytes: Data
    let width: Int
    let height: Int
    let component: MaskComponent
    let invert: Bool
    let opacity: Float
    let normalizedCoverage: Bool

    func coverage(atSourceX x: Int, y: Int, sourceWidth: Int, sourceHeight: Int) -> Float {
        guard width > 0, height > 0, sourceWidth > 0, sourceHeight > 0 else {
            return 0
        }
        let maskX = min(max((x * width) / sourceWidth, 0), width - 1)
        let maskY = min(max((y * height) / sourceHeight, 0), height - 1)
        let offset = (maskY * width + maskX) * 4
        guard offset + 3 < bytes.count else { return 0 }
        let red = Float(bytes[offset]) / 255.0
        if normalizedCoverage {
            return red
        }
        let green = Float(bytes[offset + 1]) / 255.0
        let blue = Float(bytes[offset + 2]) / 255.0
        let alpha = Float(bytes[offset + 3]) / 255.0
        let baseValue: Float = {
            switch component {
            case .alpha:
                return alpha
            case .red:
                return red
            case .green:
                return green
            case .blue:
                return blue
            case .luminance:
                return red * 0.2126 + green * 0.7152 + blue * 0.0722
            }
        }()
        let adjustedValue = invert ? 1 - baseValue : baseValue
        return min(max(adjustedValue * opacity, 0), 1)
    }
}

public extension RenderedAttachment {
    func makeHistogram(channel: TextureHistogramChannel? = nil,
                       bins: Int = 256,
                       scope: TextureAnalysisScope,
                       preferredMethod: TextureHistogramComputationMethod = .cpuReadback) -> TextureHistogram? {
        makeHistogram(
            channel: channel,
            bins: bins,
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func makeHistogram(channel: TextureHistogramChannel? = nil,
                       bins: Int = 256,
                       region: MTLRegion? = nil,
                       mask: MaskDescriptor? = nil,
                       luminanceRange: TextureLuminanceRange? = nil,
                       colorRange: TextureColorRange? = nil,
                       coverageThreshold: Float = 0.5,
                       preferredMethod: TextureHistogramComputationMethod = .cpuReadback) -> TextureHistogram? {
        texture.c7.makeHistogram(
            channel: channel ?? defaultHistogramChannel,
            bins: bins,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    var defaultHistogramChannel: TextureHistogramChannel {
        if debugPolicy.interpretation == .scalarField,
           debugPolicy.prefersMonochromePreview == false {
            return .red
        }
        switch semantic {
        case .histogram, .maskCoverage, .luminance, .analysis:
            return .luminance
        case .primaryColor, .auxiliaryColor, .debug:
            return .luminance
        }
    }
}

public extension RenderedAttachmentSet {
    func makeHistogram(for semantic: RenderOutputAttachmentSemantic,
                       channel: TextureHistogramChannel? = nil,
                       bins: Int = 256,
                       scope: TextureAnalysisScope,
                       preferredMethod: TextureHistogramComputationMethod = .cpuReadback) -> TextureHistogram? {
        makeHistogram(
            for: semantic,
            channel: channel,
            bins: bins,
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func makeHistogram(for semantic: RenderOutputAttachmentSemantic,
                       channel: TextureHistogramChannel? = nil,
                       bins: Int = 256,
                       region: MTLRegion? = nil,
                       mask: MaskDescriptor? = nil,
                       luminanceRange: TextureLuminanceRange? = nil,
                       colorRange: TextureColorRange? = nil,
                       coverageThreshold: Float = 0.5,
                       preferredMethod: TextureHistogramComputationMethod = .cpuReadback) -> TextureHistogram? {
        attachment(for: semantic)?.makeHistogram(
            channel: channel,
            bins: bins,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func renderHistogramAttachment(for semantic: RenderOutputAttachmentSemantic,
                                   channel: TextureHistogramChannel? = nil,
                                   bins: Int = 256,
                                   height: Int = 64,
                                   region: MTLRegion? = nil,
                                   mask: MaskDescriptor? = nil,
                                   luminanceRange: TextureLuminanceRange? = nil,
                                   colorRange: TextureColorRange? = nil,
                                   coverageThreshold: Float = 0.5,
                                   preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedHistogramAttachment? {
        guard let attachment = attachment(for: semantic) else { return nil }
        return attachment.texture.c7.renderHistogramAttachment(
            channel: channel ?? attachment.defaultHistogramChannel,
            bins: bins,
            height: height,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func renderHistogramAttachment(for semantic: RenderOutputAttachmentSemantic,
                                   channel: TextureHistogramChannel? = nil,
                                   bins: Int = 256,
                                   height: Int = 64,
                                   scope: TextureAnalysisScope,
                                   preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedHistogramAttachment? {
        renderHistogramAttachment(
            for: semantic,
            channel: channel,
            bins: bins,
            height: height,
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }
}

public extension RenderedFrame {
    func makeHistogram(channel: TextureHistogramChannel = .luminance,
                       bins: Int = 256,
                       scope: TextureAnalysisScope,
                       preferredMethod: TextureHistogramComputationMethod = .cpuReadback) -> TextureHistogram? {
        makeHistogram(
            channel: channel,
            bins: bins,
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func makeHistogram(channel: TextureHistogramChannel = .luminance,
                       bins: Int = 256,
                       region: MTLRegion? = nil,
                       mask: MaskDescriptor? = nil,
                       luminanceRange: TextureLuminanceRange? = nil,
                       colorRange: TextureColorRange? = nil,
                       coverageThreshold: Float = 0.5,
                       preferredMethod: TextureHistogramComputationMethod = .cpuReadback) -> TextureHistogram? {
        texture.c7.makeHistogram(
            channel: channel,
            bins: bins,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func renderHistogramAttachment(channel: TextureHistogramChannel = .luminance,
                                   bins: Int = 256,
                                   height: Int = 64,
                                   region: MTLRegion? = nil,
                                   mask: MaskDescriptor? = nil,
                                   luminanceRange: TextureLuminanceRange? = nil,
                                   colorRange: TextureColorRange? = nil,
                                   coverageThreshold: Float = 0.5,
                                   preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedHistogramAttachment? {
        texture.c7.renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            region: region,
            mask: mask,
            luminanceRange: luminanceRange,
            colorRange: colorRange,
            coverageThreshold: coverageThreshold,
            preferredMethod: preferredMethod
        )
    }

    func renderHistogramAttachment(channel: TextureHistogramChannel = .luminance,
                                   bins: Int = 256,
                                   height: Int = 64,
                                   scope: TextureAnalysisScope,
                                   preferredMethod: TextureHistogramComputationMethod = .gpuMPS) -> RenderedHistogramAttachment? {
        renderHistogramAttachment(
            channel: channel,
            bins: bins,
            height: height,
            region: scope.region,
            mask: scope.mask,
            luminanceRange: scope.luminanceRange,
            colorRange: scope.colorRange,
            coverageThreshold: scope.coverageThreshold,
            preferredMethod: preferredMethod
        )
    }
}

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

public struct TextureHistogram: Sendable, Equatable {
    public let channel: TextureHistogramChannel
    public let bins: [UInt32]
    public let totalSampleCount: Int

    public init(channel: TextureHistogramChannel,
                bins: [UInt32],
                totalSampleCount: Int) {
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

        let fillColor = CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [
                CGFloat(color.0) / 255.0,
                CGFloat(color.1) / 255.0,
                CGFloat(color.2) / 255.0,
                1.0
            ]
        ) ?? CGColor(gray: 1, alpha: 1)
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

public extension MTLTextureCompatible_ {
    func makeHistogram(channel: TextureHistogramChannel = .luminance,
                       bins: Int = 256) -> TextureHistogram? {
        let clampedBins = max(1, bins)
        guard let bytes = bytes() else { return nil }
        let width = target.width
        let height = target.height
        guard width > 0, height > 0 else {
            return TextureHistogram(channel: channel, bins: [UInt32](repeating: 0, count: clampedBins), totalSampleCount: 0)
        }

        var counts = [UInt32](repeating: 0, count: clampedBins)
        let step = 4
        let scale = Float(clampedBins - 1)

        bytes.withUnsafeBytes { rawBuffer in
            let rgba = rawBuffer.bindMemory(to: UInt8.self)
            for offset in stride(from: 0, to: rgba.count, by: step) {
                let red = Float(rgba[offset]) / 255.0
                let green = Float(rgba[offset + 1]) / 255.0
                let blue = Float(rgba[offset + 2]) / 255.0
                let alpha = Float(rgba[offset + 3]) / 255.0

                let value: Float
                switch channel {
                case .luminance:
                    value = red * 0.2126 + green * 0.7152 + blue * 0.0722
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
            }
        }

        return TextureHistogram(
            channel: channel,
            bins: counts,
            totalSampleCount: width * height
        )
    }
}

public extension RenderedAttachment {
    func makeHistogram(channel: TextureHistogramChannel? = nil,
                       bins: Int = 256) -> TextureHistogram? {
        texture.c7.makeHistogram(
            channel: channel ?? defaultHistogramChannel,
            bins: bins
        )
    }

    private var defaultHistogramChannel: TextureHistogramChannel {
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
                       bins: Int = 256) -> TextureHistogram? {
        attachment(for: semantic)?.makeHistogram(channel: channel, bins: bins)
    }
}

public extension RenderedFrame {
    func makeHistogram(channel: TextureHistogramChannel = .luminance,
                       bins: Int = 256) -> TextureHistogram? {
        texture.c7.makeHistogram(channel: channel, bins: bins)
    }
}

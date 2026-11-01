//
//  ImageDynamicRangeStatistics.swift
//  Harbeth
//
//  Created by Condy on 2026/9/28.
//

import Foundation

/// Deterministic statistics over unpremultiplied linear Display P3 D65 RGBA floats; input is unchanged.
public struct ImageDynamicRangeStatistics: Codable, Equatable, Sendable {
    public let binCount: Int
    public let outputLimit: Float
    public let rgbHistogram: [[Int]]
    public let luminanceHistogram: [Int]
    public let belowBlack: Int
    public let aboveReferenceWhite: Int
    public let aboveOutputLimit: Int
    public let nonFinite: Int
    public let transparentInvalid: Int
    public let validPixelCount: Int
    public let actualPeakRGB: [Float]
    public let actualPeakLuminance: Float

    public static func analyze(_ rgba: [Float], referenceWhite: Float = 1, outputHeadroom: Float = 1, binCount: Int = 256) throws -> Self {
        guard rgba.count.isMultiple(of: 4) else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageDynamicRangeStatistics", reason: "invalidInputStride")
        }
        guard referenceWhite.isFinite, referenceWhite > 0 else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageDynamicRangeStatistics", reason: "invalidReferenceWhite")
        }
        guard outputHeadroom.isFinite, outputHeadroom >= 1 else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageDynamicRangeStatistics", reason: "invalidOutputHeadroom")
        }
        guard binCount >= 256, binCount <= 4_096 else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageDynamicRangeStatistics", reason: "invalidBinCount")
        }
        let outputLimit = referenceWhite * outputHeadroom
        guard outputLimit.isFinite else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageDynamicRangeStatistics", reason: "invalidOutputHeadroom")
        }
        var rgbHistogram = Array(repeating: Array(repeating: 0, count: binCount), count: 3)
        var luminanceHistogram = Array(repeating: 0, count: binCount)
        var belowBlack = 0
        var aboveReferenceWhite = 0
        var aboveOutputLimit = 0
        var nonFinite = 0
        var transparentInvalid = 0
        var validPixelCount = 0
        var actualPeakRGB = [Float](repeating: -.infinity, count: 3)
        var actualPeakLuminance = -Float.infinity
        for index in stride(from: 0, to: rgba.count, by: 4) {
            let r = rgba[index]
            let g = rgba[index + 1]
            let b = rgba[index + 2]
            let alpha = rgba[index + 3]
            guard r.isFinite, g.isFinite, b.isFinite, alpha.isFinite else {
                nonFinite += 1
                continue
            }
            guard alpha > 0, alpha <= 1 else {
                transparentInvalid += 1
                continue
            }
            let values = [r, g, b]
            // The input working space is Display P3 D65; use its linear luminance coefficients.
            let luminanceDouble = 0.22897456 * Double(r) + 0.69173852 * Double(g) + 0.07928691 * Double(b)
            guard luminanceDouble.isFinite else {
                nonFinite += 1
                continue
            }
            let luminance = Float(luminanceDouble)
            validPixelCount += 1
            if values.contains(where: { $0 < 0 }) { belowBlack += 1 }
            if values.contains(where: { $0 > referenceWhite }) { aboveReferenceWhite += 1 }
            if values.contains(where: { $0 > outputLimit }) { aboveOutputLimit += 1 }
            for channel in 0..<3 {
                actualPeakRGB[channel] = max(actualPeakRGB[channel], values[channel])
                rgbHistogram[channel][bin(for: values[channel], limit: outputLimit, count: binCount)] += 1
            }
            actualPeakLuminance = max(actualPeakLuminance, luminance)
            luminanceHistogram[bin(for: luminance, limit: outputLimit, count: binCount)] += 1
        }
        if validPixelCount == 0 {
            actualPeakRGB = [Float](repeating: 0, count: 3)
            actualPeakLuminance = 0
        }
        return Self(
            binCount: binCount, outputLimit: outputLimit,
            rgbHistogram: rgbHistogram, luminanceHistogram: luminanceHistogram,
            belowBlack: belowBlack, aboveReferenceWhite: aboveReferenceWhite,
            aboveOutputLimit: aboveOutputLimit, nonFinite: nonFinite,
            transparentInvalid: transparentInvalid, validPixelCount: validPixelCount,
            actualPeakRGB: actualPeakRGB, actualPeakLuminance: actualPeakLuminance
        )
    }

    private static func bin(for value: Float, limit: Float, count: Int) -> Int {
        guard value > 0 else { return 0 }
        guard value < limit else { return count - 1 }
        return min(count - 1, max(0, Int((value / limit) * Float(count))))
    }
}

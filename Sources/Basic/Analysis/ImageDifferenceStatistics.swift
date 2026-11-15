//
//  ImageDifferenceStatistics.swift
//  Harbeth
//
//  Created by Condy on 2026/11/15.
//

import CoreGraphics
import Foundation

/// 对已对齐、同色域的预乘RGBA8取RGB差异；不去预乘、不重采样、不决定是否值得展示。
public struct ImageDifferenceStatistics: Equatable, Sendable {
    public let pixelCount: Int
    public let meanChannelDelta: Double
    public let noticeablePixelRatio: Double

    public static func compare(
        _ original: RGBA8ImageBuffer,
        _ result: RGBA8ImageBuffer,
        noticeableChannelDelta: Int
    ) throws -> Self {
        guard original.width == result.width, original.height == result.height,
              original.width > 0, original.height > 0,
              original.width <= Int.max / original.height / 4,
              original.bytes.count == original.width * original.height * 4,
              result.bytes.count == original.bytes.count,
              (0...255).contains(noticeableChannelDelta),
              CFEqual(original.colorSpace, result.colorSpace) else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageDifferenceStatistics", reason: "incompatibleBuffers")
        }
        let count = original.width * original.height
        guard count <= Int.max / (255 * 3) else {
            throw HarbethError.renderPrimitiveValidationFailed(primitive: "ImageDifferenceStatistics", reason: "sampleBudgetExceeded")
        }
        var totalChannelDelta = 0
        var noticeablePixelCount = 0
        for offset in stride(from: 0, to: original.bytes.count, by: 4) {
            let red = abs(Int(original.bytes[offset]) - Int(result.bytes[offset]))
            let green = abs(Int(original.bytes[offset + 1]) - Int(result.bytes[offset + 1]))
            let blue = abs(Int(original.bytes[offset + 2]) - Int(result.bytes[offset + 2]))
            totalChannelDelta += red + green + blue
            if max(red, green, blue) > noticeableChannelDelta { noticeablePixelCount += 1 }
        }
        return Self(
            pixelCount: count,
            meanChannelDelta: Double(totalChannelDelta) / Double(count * 3),
            noticeablePixelRatio: Double(noticeablePixelCount) / Double(count)
        )
    }
}

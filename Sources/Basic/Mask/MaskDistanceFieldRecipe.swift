//
//  MaskDistanceFieldRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import Metal

/// 生成有限搜索半径内的归一化 mask 距离场。
///
/// 输出约定固定为 RGBA8 coverage texture：R/G/B 为 `0...1` 的距离，
/// 0 表示边界，1 表示超过搜索半径或不存在边界；A 始终为 1。
public struct MaskDistanceFieldRecipe: Sendable {
    public let maxDistance: Float
    public let threshold: Float

    public init(maxDistance: Float = 16, threshold: Float = 0.5) {
        self.maxDistance = Self.clampDistance(maxDistance)
        self.threshold = Self.clampUnit(threshold)
    }

    public func makeTexture(from mask: MaskDescriptor) throws -> MTLTexture {
        let coverage = try MaskProcessingRecipe(mask: mask).makeCoverageTexture()
        return try HarbethIO(
            element: coverage,
            filter: MaskDistanceField(maxDistance: maxDistance, threshold: threshold)
        ).output()
    }
}

private extension MaskDistanceFieldRecipe {
    static func clampDistance(_ value: Float) -> Float {
        guard value.isFinite else { return 16 }
        return min(max(value, 1), 64)
    }

    static func clampUnit(_ value: Float) -> Float {
        guard value.isFinite else { return 0.5 }
        return min(max(value, 0), 1)
    }
}

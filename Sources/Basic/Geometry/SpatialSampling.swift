//
//  SpatialSampling.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

/// Spatial transform sampling policy for geometry filters.
///
/// Practical sampling split for geometry filters:
/// geometry transforms should not default to nearest-neighbor sampling.
public enum SpatialSamplingMode: Int, Codable, Sendable, CaseIterable {
    /// Preserve exact texel edges. Useful for pixel art or hard mask grids.
    case nearest = 0
    /// Always use linear filtering.
    case linear = 1
    /// 优先高质量正交采样，其余路径使用线性采样。
    /// C7Transform 与四角透视缩小时增加最多 16×16 次面积采样；不承诺任意缩比严格带限。
    case adaptive = 2
}

/// Sampling behavior when a spatial transform reads beyond the source image.
public enum SpatialEdgeMode: Int, Codable, Sendable, CaseIterable {
    /// Out-of-bounds pixels become transparent.
    case transparent = 0
    /// Clamp to the closest edge texel.
    case clamp = 1
    /// Wrap around.
    case `repeat` = 2
    /// Mirror and repeat.
    case mirrorRepeat = 3
}

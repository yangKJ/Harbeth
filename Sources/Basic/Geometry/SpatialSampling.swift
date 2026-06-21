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
    /// Prefer orthogonal high-quality sampling when available, otherwise linear.
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

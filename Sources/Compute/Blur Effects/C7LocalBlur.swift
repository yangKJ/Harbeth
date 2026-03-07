//
//  C7LocalBlur.swift
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

import Foundation

/// 局部模糊滤镜
/// Local blur filter
public struct C7LocalBlur: C7FilterProtocol {
    
    /// Blur radius, from 0.0 to 100.0, default 10.0
    public var radius: Float = 10.0
    
    /// Blur center, normalized coordinates (0.0-1.0), default center
    public var center: C7Point2D = C7Point2D.center
    
    /// Blur size, normalized (0.0-1.0), default 0.5
    @ZeroOneRange public var size: Float = 0.5
    
    /// Blur softness, from 0.0 to 1.0, default 0.3
    @ZeroOneRange public var softness: Float = 0.3
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7LocalBlur")
    }
    
    public var factors: [Float] {
        return [radius, center.x, center.y, size, softness]
    }
    
    public init(radius: Float = 10.0, center: C7Point2D = C7Point2D.center, size: Float = 0.5, softness: Float = 0.3) {
        self.radius = radius
        self.center = center
        self.size = size
        self.softness = softness
    }
}

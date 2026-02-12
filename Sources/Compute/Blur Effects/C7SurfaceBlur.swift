//
//  C7SurfaceBlur.swift
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

import Foundation
import MetalKit

/// 表面模糊滤镜
public struct C7SurfaceBlur: C7FilterProtocol {
    
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    /// Fuzzy radius, range 0.0-50.0, default 8.0
    @Clamping(0.0...50.0) public var radius: Float = 8.0
    /// Threstres, range 0.0-1.0, default 0.1
    @ZeroOneRange public var threshold: Float = 0.1
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7SurfaceBlur")
    }
    
    public var factors: [Float] {
        return [radius, threshold, intensity]
    }
    
    public init(radius: Float = 8.0, threshold: Float = 0.1) {
        self.radius = radius
        self.threshold = threshold
    }
}

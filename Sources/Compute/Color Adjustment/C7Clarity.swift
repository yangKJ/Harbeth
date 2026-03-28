//
//  C7Clarity.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 清晰度滤镜
/// Clarity filter
public struct C7Clarity: C7FilterProtocol {
    
    /// 清晰度强度，0.0 到 1.0，默认 0.0
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// 半径，0.0 到 1.0，默认 0.12
    @ZeroOneRange public var radius: Float = 0.12
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Clarity")
    }
    
    public var factors: [Float] {
        return [intensity, radius]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public init(intensity: Float = 1.0, radius: Float = 0.12) {
        self.intensity = intensity
        self.radius = radius
    }
}

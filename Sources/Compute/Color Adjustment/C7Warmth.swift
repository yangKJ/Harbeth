//
//  C7Warmth.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 色温滤镜
/// Warmth filter
public struct C7Warmth: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    /// 色温调整，-1.0 到 1.0，默认 0.0
    /// -1.0 为冷色调（蓝色），1.0 为暖色调（黄色）
    @Clamping(range.min...range.max) public var warmth: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Warmth")
    }
    
    public var factors: [Float] {
        return [warmth]
    }
    
    public init(warmth: Float = range.value) {
        self.warmth = warmth
    }
}

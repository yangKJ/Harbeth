//
//  C7Fade.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 淡入淡出滤镜
/// Fade in/out filter
public struct C7Fade: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    /// 强度，0.0 到 1.0，默认 0.0
    /// 0.0 表示原始图像，1.0 表示完全淡出到白色
    @Clamping(range.min...range.max) public var intensity: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Fade")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public init(intensity: Float = range.value) {
        self.intensity = intensity
    }
}
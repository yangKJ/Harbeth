//
//  C7Shadows.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// 阴影调整滤镜
/// Shadows adjustment filter
public struct C7Shadows: C7FilterProtocol {
    
    /// Shadows adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public static let range: ParameterRange<Float, Self> = .init(min: -1, max: 1, value: 0.0)
    
    @Clamping(range.min...range.max) public var shadow: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Shadows")
    }
    
    public var factors: [Float] {
        return [shadow]
    }
    
    public init(shadow: Float = range.value) {
        self.shadow = shadow
    }
}

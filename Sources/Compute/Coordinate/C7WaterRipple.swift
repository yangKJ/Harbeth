//
//  C7WaterRipple.swift
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

import Foundation

/// 水波纹效果
public struct C7WaterRipple: C7FilterProtocol {
    
    public static let rippleRange: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    /// The waves, from 0.0 to 1.0
    @ZeroOneRange public var ripple: Float = rippleRange.value
    /// Click location, normalized
    public var touchCenter: C7Point2D = C7Point2D.center
    /// The wave size
    public var boundary: Float = 0.06
    
    public var modifier: Modifier {
        return .compute(kernel: "C7WaterRipple")
    }
    
    public var factors: [Float] {
        return [touchCenter.x, touchCenter.y, ripple, boundary]
    }
    
    public init(ripple: Float = rippleRange.value, boundary: Float = 0.06) {
        self.ripple = ripple
        self.boundary = boundary
    }
}

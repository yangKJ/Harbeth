//
//  C7WaterRipple.swift
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

import Foundation

/// 水波纹效果
public struct C7WaterRipple: C7FilterProtocol {
    
    /// Click location, normalized
    public var touchCenter: C7Point2D = C7Point2DCenter
    /// The waves, from 0.0 to 1.0
    public var ripple: Float = 0.0
    /// The wave size
    public var boundary: Float = 0.06
    
    public var modifier: Modifier {
        return .compute(kernel: "C7WaterRipple")
    }
    
    public var factors: [Float] {
        return [touchCenter.x, touchCenter.y, ripple, boundary]
    }
    
    public init() { }
}

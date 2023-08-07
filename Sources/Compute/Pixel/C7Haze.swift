//
//  C7Haze.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 去雾，类似于UV过滤器
public struct C7Haze: C7FilterProtocol {
    
    /// Strength of the color applied.
    public var distance: Float = 0
    /// Amount of color change.
    public var slope: Float = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Haze")
    }
    
    public var factors: [Float] {
        return [distance, slope]
    }
    
    public init(distance: Float = 0, slope: Float = 0) {
        self.distance = distance
        self.slope = slope
    }
}

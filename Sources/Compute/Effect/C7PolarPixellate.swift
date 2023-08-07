//
//  C7PolarPixellate.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7PolarPixellate: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.05)
    
    public var center: C7Point2D = C7Point2D.center
    
    /// The fractional pixel size, from 0.0 to 1.0, with a default of 0.05
    @ZeroOneRange public var scale: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7PolarPixellate")
    }
    
    public var factors: [Float] {
        return [scale, center.x, center.y]
    }
    
    public init(scale: Float = range.value) {
        self.scale = scale
    }
}

//
//  C7Pinch.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Pinch: C7FilterProtocol {
    
    public var center: C7Point2D = C7Point2D.center
    /// The radius from the center to apply the distortion, with a default of 0.25
    public var radius: Float = 0.5
    /// The amount of distortion to apply, from -2.0 to 2.0, with a default of 0.5
    public var scale: Float = 0.5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Pinch")
    }
    
    public var factors: [Float] {
        return [center.x, center.y, radius, scale]
    }
    
    public init(radius: Float = 0.5, scale: Float = 0.5) {
        self.radius = radius
        self.scale = scale
    }
}

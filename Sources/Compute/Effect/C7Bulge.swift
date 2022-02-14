//
//  C7Bulge.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Bulge: C7FilterProtocol {
    
    /// The center of the image (in normalized coordinates from 0 - 1.0) about which to distort, with a default of (0.5, 0.5)
    public var center: CGPoint
    
    /// The radius from the center to apply the distortion, with a default of 0.25
    public var radius: Float
    
    /// The amount of distortion to apply, from -1.0 to 1.0, with a default of 0.5
    public var scale: Float
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Bulge")
    }
    
    public var factors: [Float] {
        return [Float(center.x), Float(center.y), radius, scale]
    }
    
    public init(center: CGPoint = CGPoint(x: 0.5, y: 0.5), radius: Float = 0.25, scale: Float = 0.5) {
        self.center = center
        self.radius = radius
        self.scale = scale
    }
}

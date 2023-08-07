//
//  C7Bulge.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Bulge: C7FilterProtocol {
    
    /// 2D textures, normalized texture coordinates are used, from 0.0 to 1.0 in both x and y directions
    public var center: C7Point2D = C7Point2D.center
    /// The radius from the center to apply the distortion, with a default of 0.25
    public var radius: Float = 0.25
    /// The amount of distortion to apply, from -1.0 to 1.0, with a default of 0.5
    public var scale: Float = 0.5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Bulge")
    }
    
    public var factors: [Float] {
        return [center.x, center.y, radius, scale]
    }
    
    public init(radius: Float = 0.25, scale: Float = 0.5) {
        self.radius = radius
        self.scale = scale
    }
}

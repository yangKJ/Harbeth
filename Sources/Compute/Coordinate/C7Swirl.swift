//
//  C7Swirl.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Swirl: C7FilterProtocol {
    
    public var center: C7Point2D = C7Point2D.center
    /// The radius from the center to apply the distortion, with a default of 0.25
    public var radius: Float = 0.5
    /// The amount of twist to apply to the image
    public var angle: Float = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Swirl")
    }
    
    public var factors: [Float] {
        return [center.x, center.y, radius, angle]
    }
    
    public init(radius: Float = 0.5, angle: Float = 1) {
        self.radius = radius
        self.angle = angle
    }
}

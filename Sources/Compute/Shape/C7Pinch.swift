//
//  C7Pinch.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Pinch: C7FilterProtocol {
    
    /// 2D textures, normalized texture coordinates are used, from 0.0 to 1.0 in both x and y directions
    public var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// The radius from the center to apply the distortion, with a default of 0.25
    public var radius: Float = 0.5
    /// The amount of distortion to apply, from -2.0 to 2.0, with a default of 0.5
    public var scale: Float = 0.5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Pinch")
    }
    
    public var factors: [Float] {
        return [Float(center.x), Float(center.y), radius, scale]
    }
    
    public init() { }
}

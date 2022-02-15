//
//  C7PolarPixellate.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7PolarPixellate: C7FilterProtocol {
    
    /// 2D textures, normalized texture coordinates are used, from 0.0 to 1.0 in both x and y directions
    public var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// The fractional pixel size, split into width and height components.
    public var pixelSize: CGSize = CGSize(width: 0.05, height: 0.05)
    
    public var modifier: Modifier {
        return .compute(kernel: "C7PolarPixellate")
    }
    
    public var factors: [Float] {
        return [Float(pixelSize.width), Float(pixelSize.height), Float(center.x), Float(center.y)]
    }
    
    public init() { }
}

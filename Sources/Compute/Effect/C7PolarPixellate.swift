//
//  C7PolarPixellate.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7PolarPixellate: C7FilterProtocol {
    
    public var center: C7Point2D = C7Point2D.center
    /// The fractional pixel size, split into width and height components.
    public var pixelSize: CGSize = CGSize(width: 0.05, height: 0.05)
    
    public var modifier: Modifier {
        return .compute(kernel: "C7PolarPixellate")
    }
    
    public var factors: [Float] {
        return [Float(pixelSize.width), Float(pixelSize.height), center.x, center.y]
    }
    
    public init(pixelSize: CGSize = CGSize(width: 0.05, height: 0.05)) {
        self.pixelSize = pixelSize
    }
}

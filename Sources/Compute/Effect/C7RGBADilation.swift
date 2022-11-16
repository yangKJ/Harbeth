//
//  C7RGBADilation.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// Find the maximum value of each color channel in the range of radius, and set the maximum value to the current pixel.
public struct C7RGBADilation: C7FilterProtocol {
    
    /// Radius in pixel, with a default of 0.0
    public var pixelRadius: Int = 0
    
    public var vertical: Bool = false
    
    public var modifier: Modifier {
        return .compute(kernel: "C7RGBADilation")
    }
    
    public var factors: [Float] {
        return [Float(pixelRadius), vertical ? 1 : 0]
    }
    
    public init(pixelRadius: Int = 0) {
        self.pixelRadius = pixelRadius
    }
}

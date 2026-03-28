//
//  C7RGBADilation.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// Find the maximum value of each color channel in the range of radius, and set the maximum value to the current pixel.
public struct C7RGBADilation: C7FilterProtocol {
    
    /// Radius in pixel, with a default of 3.0
    public var pixelRadius: Int = 3
    
    public var vertical: Bool = false
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7RGBADilation")
    }
    
    public var factors: [Float] {
        return [Float(pixelRadius), vertical ? 1 : 0]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public init(pixelRadius: Int = 3) {
        self.pixelRadius = pixelRadius
    }
}

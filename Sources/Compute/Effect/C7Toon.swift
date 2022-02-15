//
//  C7Toon.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Toon: C7FilterProtocol {
    
    /// The number of color levels to represent in the final image. Default is 10.0
    public var quantizationLevels: Float = 10
    /// The sensitivity of the edge detection, with lower values being more sensitive. Ranges from 0.0 to 1.0
    public var threshold: Float = 0.2
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Toon")
    }
    
    public var factors: [Float] {
        return [threshold, quantizationLevels]
    }
    
    public init() { }
}

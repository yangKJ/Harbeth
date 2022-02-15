//
//  C7Posterize.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Posterize: C7FilterProtocol {
    
    /// The number of color levels to reduce the image space to.
    /// This ranges from 1 to 256, with a default of 10
    public var colorLevels: Float = 10
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Posterize")
    }
    
    public var factors: [Float] {
        return [colorLevels]
    }
    
    public init() { }
}

//
//  C7Saturation.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Saturation: C7FilterProtocol {
    
    /// The degree of saturation or desaturation to apply to the image, from 0 to 2.0, with a default of 1.0
    public var saturation: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Saturation")
    }
    
    public var factors: [Float] {
        return [saturation]
    }
    
    public init() { }
}

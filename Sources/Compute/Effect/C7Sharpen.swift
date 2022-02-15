//
//  C7Sharpen.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Sharpen: C7FilterProtocol {
    
    /// Change the opacity of an image, from -4.0 to 4.0, with a default of 0.0
    public var sharpeness: Float = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Sharpen")
    }
    
    public var factors: [Float] {
        return [sharpeness]
    }
    
    public init() { }
}

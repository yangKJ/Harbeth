//
//  C7Sharpen.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Sharpen: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -4.0, max: 4.0, value: 0.0)
    
    /// Change the opacity of an image, from -4.0 to 4.0, with a default of 0.0
    public var sharpeness: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Sharpen")
    }
    
    public var factors: [Float] {
        return [sharpeness]
    }
    
    public init(sharpeness: Float = range.value) {
        self.sharpeness = sharpeness
    }
}

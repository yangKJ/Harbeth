//
//  C7Sketch.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Sketch: C7FilterProtocol {
    
    /// Adjusts the dynamic range of the filter.
    /// Higher values lead to stronger edges, but can saturate the intensity colorspace.
    public var edgeStrength: Float = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Sketch")
    }
    
    public var factors: [Float] {
        return [edgeStrength]
    }
    
    public init(edgeStrength: Float = 1) {
        self.edgeStrength = edgeStrength
    }
}

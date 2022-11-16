//
//  C7ThresholdSketch.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7ThresholdSketch: C7FilterProtocol {
    
    /// Adjusts the dynamic range of the filter.
    /// Higher values lead to stronger edges, but can saturate the intensity colorspace.
    public var edgeStrength: Float = 1
    /// Any edge above this threshold will be black, and anything below white. Ranges from 0.0 to 1.0
    public var threshold: Float = 0.25
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ThresholdSketch")
    }
    
    public var factors: [Float] {
        return [edgeStrength, threshold]
    }
    
    public init(edgeStrength: Float = 1, threshold: Float = 0.25) {
        self.edgeStrength = edgeStrength
        self.threshold = threshold
    }
}

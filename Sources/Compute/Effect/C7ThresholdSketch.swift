//
//  C7ThresholdSketch.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

/// 阀值素描感滤镜
public struct C7ThresholdSketch: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.25)
    
    /// Any edge above this threshold will be black, and anything below white. Ranges from 0.0 to 1.0
    @ZeroOneRange public var threshold: Float = range.value

    /// Adjusts the dynamic range of the filter.
    /// Higher values lead to stronger edges, but can saturate the intensity colorspace.
    public var edgeStrength: Float = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ThresholdSketch")
    }
    
    public var factors: [Float] {
        return [edgeStrength, threshold]
    }
    
    public init(edgeStrength: Float = 1, threshold: Float = range.value) {
        self.edgeStrength = edgeStrength
        self.threshold = threshold
    }
}

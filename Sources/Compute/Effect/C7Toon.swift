//
//  C7Toon.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Toon: C7FilterProtocol {
    
    public static let thresholdRange: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.2)
    
    /// The sensitivity of the edge detection, with lower values being more sensitive. Ranges from 0.0 to 1.0
    @ZeroOneRange public var threshold: Float = thresholdRange.value
    
    /// The number of color levels to represent in the final image. Default is 10.0
    public var quantizationLevels: Float = 10
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Toon")
    }
    
    public var factors: [Float] {
        return [threshold, quantizationLevels]
    }
    
    public init(quantizationLevels: Float = 10, threshold: Float = thresholdRange.value) {
        self.quantizationLevels = quantizationLevels
        self.threshold = threshold
    }
}

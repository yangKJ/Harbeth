//
//  C7Gamma.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 灰度系数
public struct C7Gamma: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 3.0, value: 1.0)
    
    /// The adjusted gamma, from 0 to 3.0, with a default of 1.0
    public var gamma: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Gamma")
    }
    
    public var factors: [Float] {
        return [gamma]
    }
    
    public init(gamma: Float = range.value) {
        self.gamma = gamma
    }
}

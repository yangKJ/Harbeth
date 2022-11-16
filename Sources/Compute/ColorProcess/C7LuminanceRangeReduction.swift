//
//  C7LuminanceRangeReduction.swift
//  Harbeth
//
//  Created by Condy on 2022/2/23.
//

import Foundation

public struct C7LuminanceRangeReduction: C7FilterProtocol {
    
    public var rangeReductionFactor: Float = 0.6
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LuminanceRangeReduction")
    }
    
    public var factors: [Float] {
        return [rangeReductionFactor]
    }
    
    public init(rangeReductionFactor: Float = 0.6) {
        self.rangeReductionFactor = rangeReductionFactor
    }
}

//
//  C7MeanBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

/// 均值模糊效果
public struct C7MeanBlur: C7FilterProtocol {
    
    public var radius: Float = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7MeanBlur")
    }
    
    public var factors: [Float] {
        return [radius]
    }
    
    public init(radius: Float = 1) {
        self.radius = radius
    }
}

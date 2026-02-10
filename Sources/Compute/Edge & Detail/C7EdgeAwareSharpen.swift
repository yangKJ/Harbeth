//
//  C7EdgeAwareSharpen.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// 只在边缘区域锐化，避免噪点放大
/// Sharpen only in the edge area to avoid noise amplification
public struct C7EdgeAwareSharpen: C7FilterProtocol {
    
    @ZeroOneRange public var amount: Float
    
    @ZeroOneRange public var edgeThreshold: Float = 0.3
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7EdgeAwareSharpen")
    }
    
    public var factors: [Float] {
        return [amount, edgeThreshold]
    }
    
    public init(amount: Float, edgeThreshold: Float = 0.3) {
        self.amount = amount
        self.edgeThreshold = edgeThreshold
    }
}

//
//  C7Canny.swift
//  Harbeth
//
//  Created by Condy on 2026/2/7.
//

import Foundation

/// Canny边缘检测滤镜
public struct C7Canny: C7FilterProtocol {
    
    @ZeroOneRange public var threshold1: Float = 0.2
    
    @ZeroOneRange public var threshold2: Float = 0.4
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Canny")
    }
    
    public var factors: [Float] {
        return [threshold1, threshold2]
    }
    
    public init(threshold1: Float = 0.2, threshold2: Float = 0.4) {
        self.threshold1 = max(0.01, min(0.99, threshold1))
        self.threshold2 = max(self.threshold1 + 0.01, min(1.0, threshold2))
    }
}

//
//  C7Exposure.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

/// 曝光效果
public struct C7Exposure: C7FilterProtocol {
    
    public var exposure: Float = 0.0
    
    public var modifier: Modifier {
        return .compute(kernel: "Exposure")
    }
    
    public var factors: [Float] {
        return [exposure]
    }
    
    public init(exposure: Float = 0.0) {
        self.exposure = exposure
    }
}

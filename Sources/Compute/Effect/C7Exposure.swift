//
//  C7Exposure.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

/// 曝光效果
public struct C7Exposure: C7FilterProtocol {
    
    /// The adjusted exposure, from -10.0 to 10.0, with a default of 0.0
    public var exposure: Float
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Exposure")
    }
    
    public var factors: [Float] {
        return [exposure]
    }
    
    public init(exposure: Float = 0.0) {
        self.exposure = exposure
    }
}

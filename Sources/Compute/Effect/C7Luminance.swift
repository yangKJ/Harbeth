//
//  C7Luminance.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

/// 亮度效果
public struct C7Luminance: C7FilterProtocol {
    
    public private(set) var minLuminance: Float = 0.0
    public private(set) var maxLuminance: Float = 1.0
    
    public var luminance: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "Luminance")
    }
    
    public var factors: [Float] {
        return [luminance]
    }
    
    public init() { }
}

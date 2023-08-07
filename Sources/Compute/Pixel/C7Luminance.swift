//
//  C7Luminance.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

/// 亮度
public struct C7Luminance: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    @ZeroOneRange public var luminance: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Luminance")
    }
    
    public var factors: [Float] {
        return [luminance]
    }
    
    public init(luminance: Float = range.value) {
        self.luminance = luminance
    }
}

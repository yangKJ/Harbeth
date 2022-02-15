//
//  C7Luminance.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

public struct C7Luminance: C7FilterProtocol {
    
    public let minLuminance: Float = 0.0
    public let maxLuminance: Float = 1.0
    
    public var luminance: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Luminance")
    }
    
    public var factors: [Float] {
        return [luminance]
    }
    
    public init() { }
}

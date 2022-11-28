//
//  C7Pixellated.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/13.
//

import Foundation

/// 马赛克像素化
public struct C7Pixellated: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.05)
    
    /// Adjust the pixel color block size,  from 0.0 to 1.0, with a default of 0.05
    @ZeroOneRange public var pixelWidth: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Pixellated")
    }
    
    public var factors: [Float] {
        return [pixelWidth]
    }
    
    public init(pixelWidth: Float = range.value) {
        self.pixelWidth = pixelWidth
    }
}

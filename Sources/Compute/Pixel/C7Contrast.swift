//
//  C7Contrast.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 对比度
public struct C7Contrast: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 2.0, value: 1.0)
    
    /// The adjusted contrast, from 0 to 2.0, with a default of 1.0 being the original picture.
    public var contrast: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Contrast")
    }
    
    public var factors: [Float] {
        return [contrast]
    }
    
    public init(contrast: Float = range.value) {
        self.contrast = contrast
    }
}

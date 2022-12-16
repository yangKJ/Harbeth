//
//  C7Posterize.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

/// 海报化效果滤镜
public struct C7Posterize: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 1.0, max: 255.0, value: 10.0)
    
    /// The number of color levels to reduce the image space to.
    /// This ranges from 1 to 256, with a default of 10
    public var colorLevels: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Posterize")
    }
    
    public var factors: [Float] {
        return [colorLevels]
    }
    
    public init(colorLevels: Float = range.value) {
        self.colorLevels = colorLevels
    }
}

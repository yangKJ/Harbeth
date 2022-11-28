//
//  C7Monochrome.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 将图像转换为单色版本，根据每个像素的亮度进行着色
public struct C7Monochrome: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    /// The degree to which the specific color replaces the normal image color, from 0.0 to 1.0, with 0.0 as the default.
    @ZeroOneRange public var intensity: Float = range.value
    
    /// Keep the color scheme
    public var color: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Monochrome")
    }
    
    public var factors: [Float] {
        return [intensity] + RGBAColor(color: color).toRGB()
    }
    
    public init(intensity: Float = range.value, color: C7Color = .zero) {
        self.intensity = intensity
        self.color = color
    }
}

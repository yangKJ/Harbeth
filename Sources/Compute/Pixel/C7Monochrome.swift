//
//  C7Monochrome.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 将图像转换为单色版本，根据每个像素的亮度进行着色
public struct C7Monochrome: C7FilterProtocol {
    
    /// The degree to which the specific color replaces the normal image color
    @ZeroOneRange public var intensity: Float = R.iRange.value
    
    /// Keep the color scheme
    public var color: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Monochrome")
    }
    
    public var factors: [Float] {
        let rgb = color.c7.toRGBA()
        return [intensity] + [rgb.red, rgb.green, rgb.blue]
    }
    
    public init(intensity: Float = R.iRange.value, color: C7Color = .zero) {
        self.intensity = intensity
        self.color = color
    }
}

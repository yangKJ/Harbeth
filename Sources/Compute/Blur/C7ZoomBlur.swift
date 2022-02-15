//
//  C7ZoomBlur.swift
//  MetalQueenDemo
//
//  Created by Condy on 2022/2/10.
//

import Foundation

public struct C7ZoomBlur: C7FilterProtocol {
    
    /// A multiplier for the blur size, ranging from 0.0 on up, with a default of 0.0
    public var blurSize: Float = 0
    /// 对于 2D 纹理，采用归一化之后的纹理坐标, 在 x 轴和 y 轴方向上都是从 0.0 到 1.0
    /// For 2D textures, normalized texture coordinates are used, from 0.0 to 1.0 in both x and y directions
    public var blurCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ZoomBlur")
    }
    
    public var factors: [Float] {
        return [Float(blurCenter.x), Float(blurCenter.y), blurSize]
    }
    
    public init() { }
}

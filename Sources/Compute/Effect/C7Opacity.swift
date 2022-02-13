//
//  C7Opacity.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

/// 透明度效果，主要就是改变图片`alpha`
public struct C7Opacity: C7FilterProtocol {
    
    public private(set) var minOpacity: Float = 0.0
    public private(set) var maxOpacity: Float = 1.0
    
    public var opacity: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Opacity")
    }
    
    public var factors: [Float] {
        return [opacity]
    }
    
    public init(opacity: Float = 1.0) {
        self.opacity = opacity
    }
}

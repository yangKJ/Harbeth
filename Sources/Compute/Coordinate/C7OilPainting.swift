//
//  C7OilPainting.swift
//  Harbeth
//
//  Created by Condy on 2022/3/29.
//

import Foundation

/// 油画滤镜
public struct C7OilPainting: C7FilterProtocol {
    
    public var radius: Float = 3.0
    public var pixel: Int = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7OilPainting")
    }
    
    public var factors: [Float] {
        return [radius, Float(pixel)]
    }
    
    public init(radius: Float = 3.0, pixel: Int = 1) {
        self.radius = radius
        self.pixel = pixel
    }
}

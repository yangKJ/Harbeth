//
//  C7RedMonochromeBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// 红色单色模糊效果，呈黑白状态。
/// Red monochrome blur effect, single channel expansion.
public struct C7RedMonochromeBlur: C7FilterProtocol {
    
    /// Radius in pixel, with a default of 0.0
    public var pixelRadius: Int = 0
    
    /// Whether to blurred in horizontal direction.
    public var horizontal: Bool = true
    
    /// Whether to blurred in vertical direction.
    public var vertical: Bool = true
    
    public var modifier: Modifier {
        return .compute(kernel: "C7RedMonochromeBlur")
    }
    
    public var factors: [Float] {
        return [Float(pixelRadius), vertical ? 1:0, horizontal ? 1:0]
    }
    
    public init(pixelRadius: Int = 0) {
        self.pixelRadius = pixelRadius
    }
}

//
//  C7Opacity.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

public struct C7Opacity: C7FilterProtocol {
    
    public let minOpacity: Float = 0.0
    public let maxOpacity: Float = 1.0
    
    /// Change the opacity of an image, from -1.0 to 1.0, with a default of 0.0
    public var opacity: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Opacity")
    }
    
    public var factors: [Float] {
        return [opacity]
    }
    
    public init() { }
}

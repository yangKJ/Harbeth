//
//  C7ZoomBlur.swift
//  MetalQueenDemo
//
//  Created by Condy on 2022/2/10.
//

import Foundation

public struct C7ZoomBlur: C7FilterProtocol {
    
    /// A multiplier for the blur size, ranging from 0.0 on up, with a default of 0.0
    public var blurSize: Float
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ZoomBlur")
    }
    
    public var factors: [Float] {
        return [blurSize]
    }
    
    public init(blurSize: Float = 0) {
        self.blurSize = blurSize
    }
}

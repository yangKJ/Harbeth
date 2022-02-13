//
//  C7ZoomBlur.swift
//  MetalQueenDemo
//
//  Created by Condy on 2022/2/10.
//

import Foundation

public struct C7ZoomBlur: C7FilterProtocol {
    
    public var blurSize: Float = 0
    
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

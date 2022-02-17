//
//  C7SoulOut.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

import Foundation

public struct C7SoulOut: C7FilterProtocol {
    
    /// The soul brightness, from 0.0 to 1.0, with a default of 0.5
    public var soul: Float = 0.5
    public var maxScale: Float = 1.5
    public var maxAlpha: Float = 0.5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7SoulOut")
    }
    
    public var factors: [Float] {
        return [soul, maxScale, maxAlpha]
    }
    
    public init() { }
}

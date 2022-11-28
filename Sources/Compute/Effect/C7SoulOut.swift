//
//  C7SoulOut.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

import Foundation

/// 灵魂出窍效果
public struct C7SoulOut: C7FilterProtocol {
    
    public static let soulRange: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.5)
    
    /// The adjusted soul, from 0.0 to 1.0, with a default of 0.5
    @ZeroOneRange public var soul: Float = soulRange.value
    public var maxScale: Float = 1.5
    public var maxAlpha: Float = 0.5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7SoulOut")
    }
    
    public var factors: [Float] {
        return [soul, maxScale, maxAlpha]
    }
    
    public init(soul: Float = soulRange.value, maxScale: Float = 1.5, maxAlpha: Float = 0.5) {
        self.soul = soul
        self.maxScale = maxScale
        self.maxAlpha = maxAlpha
    }
}

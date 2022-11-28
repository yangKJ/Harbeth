//
//  C7Nostalgic.swift
//  Harbeth
//
//  Created by Condy on 2022/3/3.
//

import Foundation

/// 怀旧滤镜
public struct C7Nostalgic: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    /// The degree to which tan replaces normal image color, from 0.0 to 1.0
    @ZeroOneRange public var intensity: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Nostalgic")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public init(intensity: Float = range.value) {
        self.intensity = intensity
    }
}

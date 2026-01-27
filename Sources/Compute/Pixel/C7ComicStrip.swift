//
//  C7ComicStrip.swift
//  Harbeth
//
//  Created by Condy on 2022/3/3.
//

import Foundation

/// 连环画滤镜
public struct C7ComicStrip: C7FilterProtocol {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ComicStrip")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public init() { }
}

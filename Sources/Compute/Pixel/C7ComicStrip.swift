//
//  C7ComicStrip.swift
//  Harbeth
//
//  Created by Condy on 2022/3/3.
//

import Foundation

/// 连环画滤镜
public struct C7ComicStrip: C7FilterProtocol {
    
    /// Specifies the intensity of the operation.
    @ZeroOneRange public var intensity: Float = R.iRange.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ComicStrip")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public init() { }
}

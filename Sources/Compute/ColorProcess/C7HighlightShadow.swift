//
//  C7HighlightShadow.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 高光阴影
public struct C7HighlightShadow: C7FilterProtocol {
    
    /// Increase to lighten shadows, from 0.0 to 1.0, with 0.0 as the default.
    public var shadows: Float = 0.0
    
    /// Decrease to darken highlights, from 1.0 to 0.0, with 1.0 as the default.
    public var highlights: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7HighlightShadow")
    }
    
    public var factors: [Float] {
        return [shadows, highlights]
    }
    
    public init() { }
}

//
//  C7HighlightShadow.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 高光阴影
public struct C7HighlightShadow: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    /// Increase to lighten shadows, from 0.0 to 1.0, with 0.0 as the default.
    @ZeroOneRange public var shadows: Float = range.value
    
    /// Decrease to darken highlights, from 1.0 to 0.0, with 1.0 as the default.
    @ZeroOneRange public var highlights: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7HighlightShadow")
    }
    
    public var factors: [Float] {
        return [shadows, highlights]
    }
    
    public init(highlights: Float = range.value, shadows: Float = range.value) {
        self.highlights = highlights
        self.shadows = shadows
    }
}

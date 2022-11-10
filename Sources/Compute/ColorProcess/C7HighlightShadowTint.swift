//
//  C7HighlightShadowTint.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7HighlightShadowTint: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    /// Increase to lighten shadows, from 0.0 to 1.0, with 0.0 as the default.
    public var shadows: Float = range.value
    public var shadowsColor: C7Color = .zero
    
    /// Decrease to darken highlights, from 1.0 to 0.0, with 0.0 as the default.
    public var highlights: Float = range.value
    public var highlightsColor: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7HighlightShadowTint")
    }
    
    public var factors: [Float] {
        return [shadows, highlights] + RGBAColor(color: shadowsColor).toRGB() + RGBAColor(color: highlightsColor).toRGB()
    }
    
    public init() { }
}

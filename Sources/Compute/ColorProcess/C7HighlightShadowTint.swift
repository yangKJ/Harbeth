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
    
    /// Decrease to darken highlights, from 1.0 to 0.0, with 0.0 as the default.
    public var highlights: Float = range.value
    
    public var shadowsColor: C7Color = C7EmptyColor {
        didSet {
            shadowsColor.mt.toRGB(red: &sr, green: &sg, blue: &sb)
        }
    }
    public var highlightsColor: C7Color = C7EmptyColor {
        didSet {
            highlightsColor.mt.toRGB(red: &hr, green: &hg, blue: &hb)
        }
    }
    
    private var sr: Float = 1
    private var sg: Float = 1
    private var sb: Float = 1
    private var hr: Float = 1
    private var hg: Float = 1
    private var hb: Float = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7HighlightShadowTint")
    }
    
    public var factors: [Float] {
        return [shadows, sr, sg, sb, highlights, hr, hg, hb]
    }
    
    public init() { }
}

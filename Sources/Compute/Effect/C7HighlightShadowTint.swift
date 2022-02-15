//
//  C7HighlightShadowTint.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7HighlightShadowTint: C7FilterProtocol {
    
    /// Increase to lighten shadows, from 0.0 to 1.0, with 0.0 as the default.
    public var shadows: Float = 0.0
    
    /// Decrease to darken highlights, from 1.0 to 0.0, with 0.0 as the default.
    public var highlights: Float = 0.0
    
    public var shadowsColor: UIColor {
        didSet {
            if shadowsColor != UIColor.clear {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                shadowsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                sr = Float(r); sg = Float(g); sb = Float(b)
            }
        }
    }
    public var highlightsColor: UIColor {
        didSet {
            if highlightsColor != UIColor.clear {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                highlightsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                hr = Float(r); hg = Float(g); hb = Float(b)
            }
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
    
    public init() {
        self.shadowsColor = UIColor.clear
        self.highlightsColor = UIColor.clear
    }
}

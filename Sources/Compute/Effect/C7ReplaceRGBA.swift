//
//  C7ReplaceRGBA.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 先扣掉某种色系，然后再替换
/// Subtract a color scheme and replace it later
public struct C7ReplaceRGBA: C7FilterProtocol {
    
    /// How close a color match needs to exist to the target color to be replaced (default of 0.4)
    public var thresholdSensitivity: Float = 0.4
    /// How smoothly to blend for the color match (default of 0.1)
    public var smoothing: Float = 0.1
    /// Need to be transparent color
    public var chroma: UIColor {
        didSet {
            if chroma != UIColor.clear {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                chroma.getRed(&r, green: &g, blue: &b, alpha: &a)
                red = Float(r); green = Float(g); blue = Float(b)
            }
        }
    }
    /// The color to be replaced
    public var replaceColor: UIColor {
        didSet {
            if replaceColor != UIColor.clear {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                replaceColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                _r = Float(r); _g = Float(g); _b = Float(b); _a = Float(a)
            }
        }
    }
    
    private var red: Float = 0
    private var green: Float = 1
    private var blue: Float = 0
    private var _r: Float = 1
    private var _g: Float = 1
    private var _b: Float = 1
    private var _a: Float = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ReplaceRGBA")
    }
    
    public var factors: [Float] {
        return [thresholdSensitivity, smoothing, red, green, blue, _r, _g, _b, _a]
    }
    
    public init() {
        self.chroma = UIColor.clear
        self.replaceColor = UIColor.clear
    }
}

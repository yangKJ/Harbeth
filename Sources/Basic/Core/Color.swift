//
//  Color.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation
import class UIKit.UIColor

/// Empty color, do default
public let C7EmptyColor = UIColor.clear

extension UIColor: C7Compatible { }

extension Queen where Base: UIColor {
    
    /// Convert RGBA value
    public func toRGBA() -> C7Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.base.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b), Float(a))
    }
    
    /// Convert RGBA value, transparent color does not do processing
    public func toRGBA(red: inout Float, green: inout Float, blue: inout Float, alpha: inout Float) {
        if base == C7EmptyColor { return }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.base.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Float(r); green = Float(g); blue = Float(b); alpha = Float(a)
    }
    
    /// Convert RGB value, transparent color does not do processing
    public func toRGB(red: inout Float, green: inout Float, blue: inout Float) {
        if base == C7EmptyColor { return }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.base.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Float(r); green = Float(g); blue = Float(b)
    }
    
    /// Convert HSV
    /// - Parameters:
    ///   - hue: Hue adjustment, unit is degree, form 0 to 360.
    ///   - saturation: Saturation adjustment, from 0.0 to 1.0
    ///   - brightness: Control the shading of colors, form 0.0 to 1.0
    public func toHSV(hue: inout Float, saturation: inout Float, brightness: inout Float) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Float(h); saturation = Float(s); brightness = Float(b)
    }
    
    /// Convert HSL
    /// - Parameters:
    ///   - hue: Hue adjustment, unit is degree, form 0 to 360.
    ///   - saturation: Saturation adjustment, from 0.0 to 1.0
    ///   - luminance: Luminance adjustment, form 0.0 to 1.0
    public func toHSL(hue: inout Float, saturation: inout Float, luminance: inout Float) {
        var r: Float = 0, g: Float = 0, b: Float = 0
        self.toRGB(red: &r, green: &g, blue: &b)
        let Max: Float = max(r, g, b)
        let Min: Float = min(r, g, b)
        var h: Float = 0
        if Max == Min {
            h = 0.0
        } else if Max == r && g >= b {
            h = 60 * (g-b) / (Max-Min)
        } else if Max == r && g < b {
            h = 60 * (g-b) / (Max-Min) + 360
        } else if Max == g {
            h = 60 * (b-r) / (Max-Min) + 120
        } else if Max == b {
            h = 60 * (r-g) / (Max-Min) + 240
        }
        let l: Float = (r + g + b) / 3
        var s: Float = 0
        if l == 0 || Max == Min {
            s = 0
        } else if l > 0 && l <= 0.5 {
            s = (Max - Min) / (2*l)
        } else if l > 0.5 {
            s = (Max - Min) / (2 - 2*l)
        }
        hue = h; saturation = s; luminance = l
    }
}

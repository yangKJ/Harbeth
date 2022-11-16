//
//  C7Color+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

import Foundation

extension C7Color: C7Compatible {
    /// Empty color, Dooo default.
    /// Cannot get rgba.
    public static let zero = C7Color.clear
    
    public convenience init(hex: Int) {
        let mask = 0xFF
        let r = CGFloat((hex >> 16) & mask) / 255
        let g = CGFloat((hex >> 8) & mask) / 255
        let b = CGFloat((hex) & mask) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Queen where Base: C7Color {
    
    /// Convert RGBA value
    public func toC7RGBAColor() -> RGBAColor {
        return RGBAColor(color: base)
    }
    
    /// Convert RGBA value, transparent color does not do processing
    public func toRGBA(red: inout Float, green: inout Float, blue: inout Float, alpha: inout Float) {
        if base == C7Color.zero { return }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.base.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Float(r); green = Float(g); blue = Float(b); alpha = Float(a)
    }
    
    /// Convert RGB value, transparent color does not do processing
    public func toRGB(red: inout Float, green: inout Float, blue: inout Float) {
        if base == C7Color.zero { return }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.base.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Float(r); green = Float(g); blue = Float(b)
    }
    
    /// RGB to YUV.
    /// - See: https://en.wikipedia.org/wiki/YUV
    public var yuv: (y: CGFloat, u: CGFloat, v: CGFloat) {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1
        base.getRed(&r, green: &g, blue: &b, alpha: nil)
        let y = 0.212600 * r + 0.71520 * g + 0.07220 * b
        let u = -0.09991 * r - 0.33609 * g + 0.43600 * b
        let v = 0.615000 * r - 0.55861 * g - 0.05639 * b
        return (y, u, v)
    }
}

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
}

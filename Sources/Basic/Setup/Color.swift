//
//  Color.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// 每个通道颜色偏移量，在`-255 ~ 255`区间内
/// Each channel color offset, from 0 to 255.
public struct C7RGBAColor {
    
    public static let zero = C7RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float
    
    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

extension C7RGBAColor: Convertible {
    public func toFloatArray() -> [Float] {
        [red, green, blue, alpha]
    }
}

/// Empty color, do default
public let C7EmptyColor = C7Color.clear

extension Queen where Base: C7Color {
    
    /// Convert RGBA value
    public func toC7RGBAColor() -> C7RGBAColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.base.getRed(&r, green: &g, blue: &b, alpha: &a)
        return C7RGBAColor(red: Float(r), green: Float(g), blue: Float(b), alpha: Float(a))
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

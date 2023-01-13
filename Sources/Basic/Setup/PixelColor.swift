//
//  Color.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// RGBA色彩空间中的颜色，在`0 ~ 1`区间内
/// Pixel Color contains 4  channels, from 0 to 1.
public struct PixelColor {
    
    public static let zero = PixelColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let one  = PixelColor(red: 1, green: 1, blue: 1, alpha: 1)
    
    @ZeroOneRange public var red: Float
    @ZeroOneRange public var green: Float
    @ZeroOneRange public var blue: Float
    @ZeroOneRange public var alpha: Float
    
    public init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(white: Float, alpha: Float = 1.0) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
    
    public init(color: C7Color) {
        // See: https://developer.apple.com/documentation/uikit/uicolor/1621919-getred
        let tuple = color.mt.toRGBA()
        self.init(red: tuple.red, green: tuple.green, blue: tuple.blue, alpha: tuple.alpha)
    }
    
    public init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat = 1.0) {
        let color = C7Color(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        self.init(color: color)
    }
}

extension PixelColor {
    public func toRGBA() -> [Float] {
        [red, green, blue, alpha]
    }
    
    public func toRGB() -> [Float] {
        [red, green, blue]
    }
    
    public var components: [CGFloat] {
        [red, green, blue, alpha].map { CGFloat($0) }
    }
    
    public var greyComponents: [CGFloat] {
        [red, alpha].map { CGFloat($0) }
    }
}

extension PixelColor: Equatable {
    
    public static func == (lhs: PixelColor, rhs: PixelColor) -> Bool {
        lhs.red == rhs.red &&
        lhs.green == rhs.green &&
        lhs.blue == rhs.blue &&
        lhs.alpha == rhs.alpha
    }
}

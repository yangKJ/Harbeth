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
        let tuple = color.c7.toRGBA()
        self.init(red: tuple.red, green: tuple.green, blue: tuple.blue, alpha: tuple.alpha)
    }
    
    public init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat = 1.0) {
        let color = C7Color(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        self.init(color: color)
    }
    
    public init(hex: Int) {
        let mask = 0xFF
        let r = Float((hex >> 16) & mask) / 255
        let g = Float((hex >> 8) & mask) / 255
        let b = Float((hex) & mask) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
    
    public init(hex: String) {
        let input = hex.replacingOccurrences(of: "#", with: "").uppercased()
        var a: CGFloat = 1.0, r: CGFloat = 0.0, b: CGFloat = 0.0, g: CGFloat = 0.0
        func colorComponent(from string: String, start: Int, length: Int) -> CGFloat {
            let substring = (string as NSString).substring(with: NSRange(location: start, length: length))
            let fullHex = length == 2 ? substring : "\(substring)\(substring)"
            var hexComponent: UInt64 = 0
            Scanner(string: fullHex).scanHexInt64(&hexComponent)
            return CGFloat(Double(hexComponent) / 255.0)
        }
        switch (input.count) {
        case 3 /* #RGB */:
            r = colorComponent(from: input, start: 0, length: 1)
            g = colorComponent(from: input, start: 1, length: 1)
            b = colorComponent(from: input, start: 2, length: 1)
        case 4 /* #ARGB */:
            a = colorComponent(from: input, start: 0, length: 1)
            r = colorComponent(from: input, start: 1, length: 1)
            g = colorComponent(from: input, start: 2, length: 1)
            b = colorComponent(from: input, start: 3, length: 1)
        case 6 /* #RRGGBB */:
            r = colorComponent(from: input, start: 0, length: 2)
            g = colorComponent(from: input, start: 2, length: 2)
            b = colorComponent(from: input, start: 4, length: 2)
        case 8 /* #AARRGGBB */:
            a = colorComponent(from: input, start: 0, length: 2)
            r = colorComponent(from: input, start: 2, length: 2)
            g = colorComponent(from: input, start: 4, length: 2)
            b = colorComponent(from: input, start: 6, length: 2)
        default:
            break
        }
        self.init(red: Float(r), green: Float(g), blue: Float(b), alpha: Float(a))
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

extension PixelColor {
    
    /// The red, green, and blue values are inverted, while the alpha channel is left alone.
    public var inverted: PixelColor {
        var pixel = self
        pixel.red = 1.0 - pixel.red
        pixel.green = 1.0 - pixel.green
        pixel.blue = 1.0 - pixel.blue
        return pixel
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

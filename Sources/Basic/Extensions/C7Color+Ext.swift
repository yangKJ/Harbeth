//
//  C7Color+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

import Foundation
import CoreImage

extension C7Color: HarbethCompatible {
    /// Empty color, Dooo default. cannot get rgba.
    public static let zero = C7Color.init(white: 0, alpha: 0)
    /// Random color
    public static let random = {
        C7Color(hue: CGFloat(arc4random() % 256 / 256),
                saturation: CGFloat(arc4random() % 128 / 256) + 0.5,
                brightness: CGFloat(arc4random() % 128 / 256) + 0.5,
                alpha: 1.0)
    }()
    
    public convenience init(hex: Int) {
        let mask = 0xFF
        let r = CGFloat((hex >> 16) & mask) / 255
        let g = CGFloat((hex >> 8) & mask) / 255
        let b = CGFloat((hex) & mask) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
    
    public convenience init(hex: String) {
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
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension HarbethWrapper where Base: C7Color {
    
    public func toCIColor() -> CIColor {
        let components = base.c7.components
        return CIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
    }
    
    public func toRGBA() -> (red: Float, green: Float, blue: Float, alpha: Float) {
        let components = base.c7.components.map { Float($0) }
        return (red: components[0], green: components[1], blue: components[2], alpha: components[3])
    }
    
    /// Convert RGBA value, transparent color does not do processing
    public func toRGBA(red: inout Float, green: inout Float, blue: inout Float, alpha: inout Float) {
        if base == C7Color.zero { return }
        (red, green, blue, alpha) = base.c7.toRGBA()
    }
    
    public func linearInterpolation(directionColor: C7Color, rate: Float) -> C7Color {
        let rate = min(1, max(0, rate))
        let (fR, fG, fB, fA) = base.c7.toRGBA()
        let (tR, tG, tB, tA) = directionColor.c7.toRGBA()
        let dR = CGFloat((tR-fR) * rate + fR) / 255.0
        let dG = CGFloat((tG-fG) * rate + fR) / 255.0
        let dB = CGFloat((tB-fB) * rate + fR) / 255.0
        let dA = CGFloat((tA-fA) * rate + fA)
        return C7Color.init(red: dR, green: dG, blue: dB, alpha: dA)
    }
    
    /// Fixed `*** -getRed:green:blue:alpha: not valid for the NSColor Generic Gray Gamma 2.2 Profile colorspace 1 1;
    /// Need to first convert colorspace.
    /// See: https://stackoverflow.com/questions/67314642/color-not-valid-for-the-nscolor-generic-gray-gamma-when-creating-sktexture-fro
    /// - Returns: Color.
    func usingColorSpace_sRGB() -> C7Color {
        #if os(macOS)
        return base.usingColorSpace(.sRGB) ?? base
        #else
        return base
        #endif
    }
    
    /// Solid color image.
    /// - Parameter size: Image size.
    /// - Returns: C7Image.
    public func colorImage(with size: CGSize = .onePixel) -> C7Image? {
        #if HARBETH_COMPUTE_LIBRARY_IN_BUNDLE
        let texture = try? TextureLoader.emptyTexture(at: size)
        let filter = C7SolidColor(color: base)
        let dest = HarbethIO(element: texture, filter: filter)
        let image = (try? dest.output())?.c7.toImage()
        return image
        #else
        return nil
        #endif
    }
}

extension HarbethWrapper where Base: C7Color {
    
    /// Return a array with [red, green, blue, alpha].
    public var components: [CGFloat] {
        if base == C7Color.zero {
            return [0, 0, 0, 0]
        }
        let color = base.c7.usingColorSpace_sRGB()
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }
    
    /// Returns the HSB (hue, saturation, brightness) components.
    /// Notes that hue values are between 0 to 360, saturation values are between 0 to 1 and brightness values are between 0 to 1.
    /// - Returns: return a array with [hue, saturation, brightness].
    public func toHSBComponents() -> [CGFloat] {
        let components = base.c7.components
        let red = components[0]
        let green = components[1]
        let blue = components[2]
        let maximum = max(red, max(green, blue))
        let minimum = min(red, min(green, blue))
        var h: CGFloat = 0.0
        let s: CGFloat
        let v: CGFloat = maximum
        if maximum == 0 {
            s = 0.0
        } else {
            s = (maximum - minimum) / maximum
        }
        if maximum == minimum {
            h = 0.0
        } else if maximum == red && green >= blue {
            h = 60 * (green - blue) / (maximum - minimum)
        } else if maximum == red && green < blue {
            h = 60 * (green - blue) / (maximum - minimum) + 360.0
        } else if maximum == blue {
            h = 60 * (red - green) / (maximum - minimum) + 240.0
        } else if maximum == green {
            h = 60 * (blue - red) / (maximum - minimum) + 120.0
        }
        return [CGFloat(h), CGFloat(s), CGFloat(v)]
    }
    
    /// Returns the HSL (hue, saturation, lightness) components.
    /// Notes that hue values are between 0 to 360, saturation values are between 0 to 1 and lightness values are between 0 to 1.
    /// - Returns: return a array with [hue, saturation, lightness].
    public func toHSLComponents() -> [CGFloat] {
        let components = base.c7.components
        let red = components[0]
        let green = components[1]
        let blue = components[2]
        let maximum = max(red, max(green, blue))
        let minimum = min(red, min(green, blue))
        let delta = maximum - minimum
        guard delta != 0.0 else {
            return [0.0, 0.0, CGFloat(maximum)]
        }
        var h: CGFloat = 0.0
        let s: CGFloat
        let l: CGFloat = (maximum + minimum) / 2.0
        if l < 0.5 {
            s = delta / (maximum + minimum)
        } else {
            s = delta / (2.0 - maximum - minimum)
        }
        switch maximum {
        case red:
            h = ((green - blue) / delta) + (green < blue ? 6.0 : 0.0)
        case green:
            h = ((blue - red) / delta) + 2.0
        case blue:
            h = ((red - green) / delta) + 4.0
        default:
            break
        }
        //h /= 6.0
        return [CGFloat(h) * 60.0, CGFloat(s), CGFloat(l)]
    }
    
    /// Returns the XYZ (mix of cone response curves, luminance, quasi-equal to blue stimulation) components.
    /// Notes that X values are between 0 to 95.05, Y values are between 0 to 100.0 and Z values are between 0 to 108.9.
    /// - Returns: return a array with [X, Y, Z].
    public func toXYZComponents() -> [CGFloat] {
        let toSRGB = { (c: CGFloat) -> CGFloat in
            c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92
        }
        let components = base.c7.components
        let red = components[0]
        let green = components[1]
        let blue = components[2]
        let r = toSRGB(CGFloat(red))
        let g = toSRGB(CGFloat(green))
        let b = toSRGB(CGFloat(blue))
        let roundDecimal = { (_ x: CGFloat) -> CGFloat in
            CGFloat(Int(round(x * 10000.0))) / 10000.0
        }
        let X = roundDecimal(((r * 0.4124) + (g * 0.3576) + (b * 0.1805)) * 100.0)
        let Y = roundDecimal(((r * 0.2126) + (g * 0.7152) + (b * 0.0722)) * 100.0)
        let Z = roundDecimal(((r * 0.0193) + (g * 0.1192) + (b * 0.9505)) * 100.0)
        return [X, Y, Z]
    }
    
    /// Returns the Lab (lightness, red-green axis, yellow-blue axis) components.
    /// It is based on the CIE XYZ color space with an observer at 2° and a D65 illuminant.
    /// Notes that L values are between 0 to 100.0, a values are between -128 to 127.0 and b values are between -128 to 127.0.
    /// - Returns: return a array with [L, a, b].
    public func toLabComponents() -> [CGFloat] {
        let normalized = { (c: CGFloat) -> CGFloat in
            c > 0.008856 ? pow(c, 1.0 / 3.0) : (7.787 * c) + (16.0 / 116.0)
        }
        let xyz = toXYZComponents()
        let normalizedX = normalized(xyz[0] / 95.05)
        let normalizedY = normalized(xyz[1] / 100.0)
        let normalizedZ = normalized(xyz[2] / 108.9)
        let roundDecimal = { (_ x: CGFloat) -> CGFloat in
            CGFloat(Int(round(x * 1000.0))) / 1000.0
        }
        let L = roundDecimal(116.0 * normalizedY - 16.0)
        let a = roundDecimal(500.0 * (normalizedX - normalizedY))
        let b = roundDecimal(200.0 * (normalizedY - normalizedZ))
        return [L, a, b]
    }
    
    /// A color is described as a Y component (luma) and two chroma components U and V.
    /// - See: https://en.wikipedia.org/wiki/YUV
    /// - Returns: return a array with [Y, U, V].
    public func toYUVComponents() -> [CGFloat] {
        let components = base.c7.components
        let r = components[0]
        let g = components[1]
        let b = components[2]
        let y = 0.212600 * r + 0.71520 * g + 0.07220 * b
        let u = -0.09991 * r - 0.33609 * g + 0.43600 * b
        let v = 0.615000 * r - 0.55861 * g - 0.05639 * b
        return [y, u, v]
    }
}

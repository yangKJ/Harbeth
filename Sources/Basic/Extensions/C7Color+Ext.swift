//
//  C7Color+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

import Foundation

extension C7Color: HarbethCompatible {
    /// Empty color, Dooo default. cannot get rgba.
    public static let zero = C7Color.init(white: 0, alpha: 0)
    /// Random color
    public static var random: C7Color {
        get {
            return C7Color(hue: CGFloat(arc4random() % 256 / 256),
                           saturation: CGFloat(arc4random() % 128 / 256) + 0.5,
                           brightness: CGFloat(arc4random() % 128 / 256) + 0.5,
                           alpha: 1.0)
        }
    }

    public convenience init(hex: Int, alpha: CGFloat) {
        let mask = 0xFF
        let r = CGFloat((hex >> 16) & mask) / 255
        let g = CGFloat((hex >> 8) & mask) / 255
        let b = CGFloat((hex) & mask) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    public convenience init(hex: String) {
        let (r, g, b, a) = hex.c7.hex2RGBA()
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension HarbethWrapper where Base: C7Color {

    public func toRGBA() -> (red: Float, green: Float, blue: Float, alpha: Float) {
        let components = base.c7.components.map { Float($0) }
        return (red: components[0], green: components[1], blue: components[2], alpha: components[3])
    }

    /// Convert the RGB component into a three-dimensional SIMD vector.
    public func toSIMD3() -> SIMD3<Float> {
        let rgba = toRGBA()
        return SIMD3<Float>(rgba.red, rgba.green, rgba.blue)
    }

    /// Convert the RGBA component into a four-dimensional SIMD vector.
    public func toSIMD4() -> SIMD4<Float> {
        let rgba = toRGBA()
        return SIMD4<Float>(rgba.red, rgba.green, rgba.blue, rgba.alpha)
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
        guard let texture = try? TextureLoader.makeTexture(at: size) else {
            return nil
        }
        let filter = C7SolidColor(color: base)
        let dest = try? HarbethIO(element: texture, filter: filter).output()
        return dest?.c7.toImage()
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
        let h: CGFloat
        let s: CGFloat
        if maximum == 0 {
            s = 0.0
        } else {
            s = (maximum - minimum) / maximum
        }
        if maximum == red && green >= blue {
            h = 60 * (green - blue) / (maximum - minimum)
        } else if maximum == red && green < blue {
            h = 60 * (green - blue) / (maximum - minimum) + 360.0
        } else if maximum == blue {
            h = 60 * (red - green) / (maximum - minimum) + 240.0
        } else if maximum == green {
            h = 60 * (blue - red) / (maximum - minimum) + 120.0
        } else {
            h = 0.0
        }
        return [h, s, maximum]
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
        let h: CGFloat
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
            h = 0.0
        }
        //h /= 6.0
        return [h * 60.0, s, l]
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

extension C7Color {
    /// Defines the mode (i.e color space) used for grayscaling.
    /// https://en.wikipedia.org/wiki/Lightness#Lightness_and_human_perception
    public enum GrayedMode {
        /// Weighted average method: The weighted average in RGB is used as gray.
        /// Because the human eye is sensitive to red, green and blue, it is necessary to calculate the grayscale.
        /// This coefficient is mainly derived according to the sensitivity of the human eye to the three primary colors of R, G and B.
        case weighted
        /// This algorithm is called Luminosity, or brightness algorithm.
        case luminosity
        /// The process of desaturation is to convert RGB to HLS and then set the saturation to 0.
        case lightness
        /// Average method: RGB average value as gray.
        case average
        /// Maximum method: the maximum value in RGB as gray.
        case maximum
        /// Minimum method: the minimum value in RGB as gray.
        case minimum
    }
}

extension HarbethWrapper where Base: C7Color {

    /// The red, green, and blue values are inverted, while the alpha channel is left alone.
    public var inverted: C7Color {
        let components = base.c7.components
        let r = 1.0 - components[0]
        let g = 1.0 - components[1]
        let b = 1.0 - components[2]
        return C7Color.init(red: r, green: g, blue: b, alpha: components[3])
    }

    /// A boolean value to know whether the color is light. If false the color is light, dark otherwise.
    /// Determines if the color object is dark or light.
    /// It is useful when you need to know whether you should display the text in black or white.
    public var isDark: Bool {
        let components = base.c7.components
        let brightness = ((components[0] * 299.0) + (components[1] * 587.0) + (components[2] * 114.0)) / 1000.0
        return brightness > 0.5
    }

    /// A float value representing the luminance of the current color. May vary from 0 to 1.0.
    /// You can read more here: https://www.w3.org/TR/WCAG20/#relativeluminancedef.
    public var luminance: CGFloat {
        let rgb = base.c7.components.prefix(3).map {
            guard $0 <= 0.03928 else {
                return CGFloat(powf(Float(($0 + 0.055)) / 1.055, 2.4))
            }
            return CGFloat($0 / 12.92)
        }
        return (0.2126 * rgb[0]) + (0.7152 * rgb[1]) + (0.0722 * rgb[2])
    }

    /// Returns a float value representing the contrast ratio between 2 pixel colors.
    /// https://www.w3.org/TR/WCAG20-TECHS/G18.html
    /// - Parameter color: The other pixel color to compare with.
    /// - Returns: A CGFloat representing contrast value.
    public func contrastRatio(with color: C7Color) -> CGFloat {
        let luminance0 = base.c7.luminance
        let luminance1 = color.c7.luminance
        let l1 = max(luminance0, luminance1)
        let l2 = min(luminance0, luminance1)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    /// A pixel color object converted to grayscale. Similar with desaturated.
    /// - Parameter mode: Defines the mode (i.e color space) used for grayscaling.
    /// - Returns: A grayscale pixel color.
    public func grayscaled(mode: C7Color.GrayedMode = .weighted) -> C7Color {
        let components = base.c7.components
        let lightness = mode.lightness(r: components[0], g: components[1], b: components[2])
        let l = min(max(lightness, 0.0), 1.0)
        /// Hue to RGB helper function
        let hueToRGB = { (m1: CGFloat, m2: CGFloat, h: CGFloat) -> CGFloat in
            let hue = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
            if hue * 6 < 1.0 {
                return m1 + ((m2 - m1) * hue * 6.0)
            } else if hue * 2.0 < 1.0 {
                return m2
            } else if hue * 3.0 < 1.9999 {
                return m1 + ((m2 - m1) * ((2.0 / 3.0) - hue) * 6.0)
            }
            return m1
        }
        let m2 = l <= 0.5 ? l : 0.0
        let m1 = l * 2.0 - m2
        let r = hueToRGB(m1, m2, 1.0/3.0)
        let g = hueToRGB(m1, m2, 0.0)
        let b = hueToRGB(m1, m2, -1.0/3.0)
        return C7Color.init(red: r, green: g, blue: b, alpha: components[3])
    }
}

extension C7Color.GrayedMode {
    func lightness(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
        switch self {
        case .weighted, .luminosity:
            return (0.299 * r) + (0.587 * g) + (0.114 * b)
        case .lightness:
            return 0.5 * (max(r, g, b) + min(r, g, b))
        case .average:
            return (r + g + b) / 3.0
        case .maximum:
            return max(r, g, b)
        case .minimum:
            return min(r, g, b)
        }
    }
}

//
//  C7Color+Driver.swift
//  Harbeth
//
//  Created by Condy on 2023/12/1.
//

import Foundation

extension C7Color {
    /// Defines the mode (i.e color space) used for grayscaling.
    /// https://en.wikipedia.org/wiki/Lightness#Lightness_and_human_perception
    public enum GrayedMode {
        /// Weighted average method: The weighted average in RGB is used as gray.
        /// Because the human eye is sensitive to red, green and blue, it is necessary to calculate the grayscale.
        /// This coefficient is mainly derived according to the sensitivity of the human eye to the three primary colors of R, G and B.
        case weighted
        /// HSL lightness
        case lightness
        /// Average method: RGB average value as gray.
        case average
        /// Maximum method: the maximum value in RGB as gray.
        case maximum
        
        func lightness(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
            switch self {
            case .weighted:
                return (0.299 * r) + (0.587 * g) + (0.114 * b)
            case .lightness:
                return 0.5 * (max(r, g, b) + min(r, g, b))
            case .average:
                return (r + g + b) / 3.0
            case .maximum:
                return max(r, g, b)
            }
        }
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
    /// - Parameter pixelColor: The other pixel color to compare with.
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
        let h = 0.0
        let s = 0.0
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
        let m2 = l <= 0.5 ? l * (s + 1.0) : (l + s) - (l * s)
        let m1 = (l * 2.0) - m2
        let r = hueToRGB(m1, m2, h + (1.0 / 3.0))
        let g = hueToRGB(m1, m2, h)
        let b = hueToRGB(m1, m2, h - (1.0 / 3.0))
        return C7Color.init(red: r, green: g, blue: b, alpha: components[3])
    }
}

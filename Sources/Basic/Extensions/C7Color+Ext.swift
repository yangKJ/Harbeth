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

extension Queen where Base: C7Color {
    
    /// Convert RGBA value
    public func toC7RGBAColor() -> RGBAColor {
        return RGBAColor(color: base)
    }
    
    public func toRGBA() -> (red: Float, green: Float, blue: Float, alpha: Float) {
        if base == C7Color.zero { return (0,0,0,0) }
        let color = base.mt.usingColorSpace_sRGB()
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b), Float(a))
    }
    
    /// Convert RGBA value, transparent color does not do processing
    public func toRGBA(red: inout Float, green: inout Float, blue: inout Float, alpha: inout Float) {
        if base == C7Color.zero { return }
        let (r, g, b, a) = base.mt.toRGBA()
        red = r; green = g; blue = b; alpha = a;
    }
    
    /// RGB to YUV.
    /// - See: https://en.wikipedia.org/wiki/YUV
    public var yuv: (y: Float, u: Float, v: Float) {
        if base == C7Color.zero { return (0,0,0) }
        let (r, g, b, _) = base.mt.toRGBA()
        let y = 0.212600 * r + 0.71520 * g + 0.07220 * b
        let u = -0.09991 * r - 0.33609 * g + 0.43600 * b
        let v = 0.615000 * r - 0.55861 * g - 0.05639 * b
        return (Float(y), Float(u), Float(v))
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
}

#if HARBETH_COMPUTE // Compute module
extension Queen where Base: C7Color {
    
    /// Create a solid color image.
    /// - Parameters:
    ///   - color: Indicates the color.
    ///   - size: Indicates the size of the solid color diagram.
    /// - Returns: Solid color graph.
    public func colorImage(with size: CGSize = CGSize(width: 1, height: 1)) -> C7Image? {
        let width  = Int(size.width > 0 ? size.width : 1)
        let height = Int(size.height > 0 ? size.height : 1)
        let texture = Processed.destTexture(width: width, height: height)
        let filter = C7SolidColor.init(color: base)
        let result = try? Processed.IO(inTexture: texture, outTexture: texture, filter: filter)
        return result?.toImage()
    }
}
#endif

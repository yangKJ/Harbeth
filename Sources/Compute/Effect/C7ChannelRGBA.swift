//
//  C7ChannelRGBA.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7ChannelRGBA: C7FilterProtocol {

    /// Modify the value of color single channel, `1` keeps the source channel color, `>1` adds red pigment, `<1` reduces red pigment
    public var red:   Float = 1
    public var green: Float = 1
    public var blue:  Float = 1
    public var alpha: Float = 1
    /// Transparent colors are not processed, Will directly modify the overall color scheme
    public var color: UIColor {
        didSet {
            if color != UIColor.clear {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                red = Float(r); green = Float(g); blue = Float(b); alpha = Float(a)
            }
        }
    }
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ChannelRGBA")
    }
    
    public var factors: [Float] {
        return [red, green, blue, alpha]
    }
    
    public init() {
        self.color = UIColor.clear
    }
}

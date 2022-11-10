//
//  Color.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// 每个通道颜色偏移量，在`-255 ~ 255`区间内
/// Each channel color offset, from 0 to 255.
public struct RGBAColor {
    
    public static let zero = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    
    public var red:   Float = 0
    public var green: Float = 0
    public var blue:  Float = 0
    public var alpha: Float = 0
    
    public init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(color: C7Color) {
        color.mt.toRGBA(red: &self.red, green: &self.green, blue: &self.blue, alpha: &self.alpha)
    }
}

extension RGBAColor: Convertible {
    public func toFloatArray() -> [Float] {
        [red, green, blue, alpha]
    }
    
    public func toRGB() -> [Float] {
        [red, green, blue]
    }
}

extension RGBAColor: Equatable {
    
    public static func == (lhs: RGBAColor, rhs: RGBAColor) -> Bool {
        lhs.red == rhs.red &&
        lhs.green == rhs.green &&
        lhs.blue == rhs.blue &&
        lhs.alpha == rhs.alpha
    }
}

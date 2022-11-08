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

extension C7RGBAColor: Equatable {
    
    public static func == (lhs: C7RGBAColor, rhs: C7RGBAColor) -> Bool {
        lhs.red == rhs.red &&
        lhs.green == rhs.green &&
        lhs.blue == rhs.blue &&
        lhs.alpha == rhs.alpha
    }
}

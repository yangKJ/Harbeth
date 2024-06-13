//
//  RGBA.swift
//  Harbeth
//
//  Created by Condy on 2024/5/1.
//

import Foundation

public struct RGBA<Channel> {
    public var red: Channel
    public var green: Channel
    public var blue: Channel
    public var alpha: Channel
    
    public init(red: Channel, green: Channel, blue: Channel, alpha: Channel) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(gray: Channel, alpha: Channel) {
        self.init(red: gray, green: gray, blue: gray, alpha: alpha)
    }
    
    public func map<T>(_ transform: (Channel) -> T) -> RGBA<T> {
        return RGBA<T>(
            red: transform(red),
            green: transform(green),
            blue: transform(blue),
            alpha: transform(alpha)
        )
    }
}

extension RGBA where Channel : UnsignedInteger & FixedWidthInteger {
    
    public init(red: Channel, green: Channel, blue: Channel) {
        self.init(red: red, green: green, blue: blue, alpha: .max)
    }
}

extension RGBA where Channel : FloatingPoint {
    
    public init(red: Channel, green: Channel, blue: Channel) {
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
    
    public var gray: Channel {
        return (red + green + blue) / 3
    }
}

extension RGBA where Channel == UInt8 {
    
    public init(_ hex: UInt32) {
        self.init(red: UInt8((hex >> 24) & 0xFF), green: UInt8((hex >> 16) & 0xFF), blue: UInt8((hex >> 8) & 0xFF), alpha: UInt8(hex & 0xFF))
    }
}

extension RGBA: Equatable where Channel : Equatable {
    
    public static func ==(lhs: RGBA<Channel>, rhs: RGBA<Channel>) -> Bool {
        return lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue && lhs.alpha == rhs.alpha
    }
    
    public static func !=(lhs: RGBA<Channel>, rhs: RGBA<Channel>) -> Bool {
        return lhs.red != rhs.red || lhs.green != rhs.green || lhs.blue != rhs.blue || lhs.alpha != rhs.alpha
    }
}

extension RGBA: AdditiveArithmetic where Channel : AdditiveArithmetic {
    
    public static var zero: RGBA<Channel> {
        RGBA<Channel>(red: .zero, green: .zero, blue: .zero, alpha: .zero)
    }
    
    public static func +(_ lhs: RGBA<Channel>, _ rhs: RGBA<Channel>) -> RGBA<Channel> {
        return RGBA<Channel>(
            red  : lhs.red   + rhs.red,
            green: lhs.green + rhs.green,
            blue : lhs.blue  + rhs.blue,
            alpha: lhs.alpha + rhs.alpha
        )
    }
    
    public static func +=(_ lhs: inout RGBA<Channel>, _ rhs: RGBA<Channel>) {
        lhs.red   += rhs.red
        lhs.green += rhs.green
        lhs.blue  += rhs.blue
        lhs.alpha += rhs.alpha
    }
    
    public static func -(_ lhs: RGBA<Channel>, _ rhs: RGBA<Channel>) -> RGBA<Channel> {
        return RGBA<Channel>(
            red  : lhs.red   - rhs.red,
            green: lhs.green - rhs.green,
            blue : lhs.blue  - rhs.blue,
            alpha: lhs.alpha - rhs.alpha
        )
    }
    
    public static func -=(_ lhs: inout RGBA<Channel>, _ rhs: RGBA<Channel>) {
        lhs.red   -= rhs.red
        lhs.green -= rhs.green
        lhs.blue  -= rhs.blue
        lhs.alpha -= rhs.alpha
    }
}

extension RGBA: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return description
    }
    
    public var description: String {
        if let zelf = self as? RGBA<UInt8> {
            return String(format: "#%02X%02X%02X%02X", arguments: [zelf.red, zelf.green, zelf.blue, zelf.alpha])
        } else {
            return "RGBA(red: \(red), green: \(green), blue: \(blue), alpha: \(alpha))"
        }
    }
}

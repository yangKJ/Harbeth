//
//  Color+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/12/1.
//

import Foundation
import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Color {
    
    /// Creates a color from an hex integer, e.g. 0xD6A5A4.
    /// - Parameter hex: A hexa-decimal UInt64 that represents a color.
    public init(hex: Int) {
        let mask = 0xFF
        let r = Double((hex >> 16) & mask) / 255
        let g = Double((hex >> 8) & mask) / 255
        let b = Double((hex) & mask) / 255
        self.init(red: r, green: g, blue: b, opacity: 1.0)
    }
    
    /// Creates a color from an hex string, e.g. "#D6A5A4".
    /// Support hex string `#RGB`,`RGB`,`#RGBA`,`RGBA`,`#RRGGBB`,`RRGGBB`,`#RRGGBBAA`,`RRGGBBAA`.
    /// - Parameter hex: A hexa-decimal color string representation.
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
        case 4 /* #RGBA */:
            r = colorComponent(from: input, start: 0, length: 1)
            g = colorComponent(from: input, start: 1, length: 1)
            b = colorComponent(from: input, start: 2, length: 1)
            a = colorComponent(from: input, start: 3, length: 1)
        case 6 /* #RRGGBB */:
            r = colorComponent(from: input, start: 0, length: 2)
            g = colorComponent(from: input, start: 2, length: 2)
            b = colorComponent(from: input, start: 4, length: 2)
        case 8 /* #RRGGBBAA */:
            r = colorComponent(from: input, start: 0, length: 2)
            g = colorComponent(from: input, start: 2, length: 2)
            b = colorComponent(from: input, start: 4, length: 2)
            a = colorComponent(from: input, start: 6, length: 2)
        default:
            break
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

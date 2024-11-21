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
        let (r, g, b, a) = hex.c7.hex2RGBA()
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

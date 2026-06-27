//
//  C7PixelFormatChange.swift
//  Harbeth
//
//  Created by Condy on 2026/6/25.
//

import Foundation

public struct C7PixelFormatChange: C7FilterProtocol {

    public var modifier: ModifierEnum {
        .compute(kernel: "C7PixelFormatChange")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init() {}
}

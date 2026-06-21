//
//  C7LanczosResize.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

public struct C7LanczosResize: C7FilterProtocol {

    public var width: Float
    public var height: Float

    public var modifier: ModifierEnum {
        .compute(kernel: "C7LanczosResize")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public func resize(input size: C7Size) -> C7Size {
        Placement.fit.resize(width: width, height: height, size: size)
    }

    public init(size: CGSize) {
        self.width = Float(size.width)
        self.height = Float(size.height)
    }

    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }
}

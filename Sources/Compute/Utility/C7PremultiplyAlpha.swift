//
//  C7PremultiplyAlpha.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 将 non-premultiplied RGBA 转为 premultiplied。
public struct C7PremultiplyAlpha: C7FilterProtocol {

    public var modifier: ModifierEnum {
        .compute(kernel: "C7PremultiplyAlpha")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init() {}
}

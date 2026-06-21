//
//  C7ForceOpaqueAlpha.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation

/// 将输出 alpha 强制为 1，同时保持 RGB 不变。
public struct C7ForceOpaqueAlpha: C7FilterProtocol {

    public var modifier: ModifierEnum {
        .compute(kernel: "C7ForceOpaqueAlpha")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init() {}
}

//
//  C7AppleLogDecode.swift
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

import Foundation
import MetalKit

/// Apple Log解码滤镜
/// 将Apple Log编码的图像转换为线性空间，用于处理HDR内容
/// Convert Apple Log-encoded images into linear space for processing HDR content
public struct C7AppleLogDecode: C7FilterProtocol {
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7AppleLogDecode")
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public init() { }
}

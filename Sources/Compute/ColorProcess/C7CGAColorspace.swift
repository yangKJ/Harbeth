//
//  C7CGAColorspace.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// 图像CGA色彩滤镜，形成黑、浅蓝、紫色块的画面
public struct C7CGAColorspace: C7FilterProtocol {
    
    public var modifier: Modifier {
        return .compute(kernel: "C7CGAColorspace")
    }
    
    public init() { }
}

//
//  C7Storyboard.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

/// 分镜滤镜
public struct C7Storyboard: C7FilterProtocol {
    
    /// 分为`N x N`个屏幕
    public var N: Int = 2
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Storyboard")
    }
    
    public var factors: [Float] {
        return [Float(N)]
    }
    
    public init(ranks: Int = 2) {
        self.N = ranks
    }
}

//
//  C7Storyboard.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

/// 分镜滤镜
public struct C7Storyboard: C7FilterProtocol {
    
    /// It is divided into `ranks²` screens.
    @Clamping(1...Int.max) public var ranks: Int = 2
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Storyboard")
    }
    
    public var factors: [Float] {
        return [Float(ranks)]
    }
    
    public init(ranks: Int = 2) {
        self.ranks = ranks
    }
}

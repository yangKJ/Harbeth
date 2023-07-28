//
//  C7Pow.swift
//  Harbeth
//
//  Created by Condy on 2023/7/28.
//

import Foundation

public struct C7Pow: C7FilterProtocol {
    
    public var value: Float = 0.2
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Pow")
    }
    
    public var factors: [Float] {
        return [value]
    }
    
    public init(value: Float = 0.2) {
        self.value = value
    }
}

//
//  C7Mirror.swift
//  Harbeth
//
//  Created by Condy on 2025/7/7.
//

import Foundation

public struct C7Mirror: C7FilterProtocol {
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Mirror")
    }
    
    public init() { }
}

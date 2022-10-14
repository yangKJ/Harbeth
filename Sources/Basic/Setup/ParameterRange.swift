//
//  ParameterRange.swift
//  Harbeth
//
//  Created by Condy on 2022/10/14.
//

import Foundation

public struct ParameterRange<T: Comparable, Target> {
    
    public let min: T
    public let max: T
    
    public init(min: T, max: T) {
        self.min = min
        self.max = max
    }
}

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
    public let value: T
    
    /// Initialize the parameter range.
    /// - Parameters:
    ///   - min: Indicates the minimum value
    ///   - max: Indicates the maximum value
    ///   - value: Indicates the default value
    public init(min: T, max: T, value: T) {
        self.min = min
        self.max = max
        self.value = value
    }
}

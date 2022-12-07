//
//  RangeWrapper.swift
//  Harbeth
//
//  Created by Condy on 2022/12/7.
//

import Foundation

/// 范围包装器
/// Extra argument 'wrappedValue' in call. This is because `radius` is set to the default value `1`.
/// Example`: @Range(min: 0, max: 2, defult: 0.5) public var radius: Float // = 1
@propertyWrapper public struct Range<T: Comparable> {
    
    let min_: T
    let max_: T
    
    public var wrappedValue: T {
        didSet {
            wrappedValue = min(max_, max(min_, wrappedValue))
        }
    }
    
    public init(min: T, max: T, defult: T) {
        self.min_ = min
        self.max_ = max
        self.wrappedValue = Swift.min(max, Swift.max(min, defult))
    }
}

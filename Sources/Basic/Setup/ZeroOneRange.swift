//
//  ZeroOneRange.swift
//  Harbeth
//
//  Created by Condy on 2022/11/25.
//

import Foundation

/// 0.0 ~ 1.0 范围区间属性包装器
/// 0.0 ~ 1.0 Range Interval Property Packer.
@propertyWrapper public struct ZeroOneRange {
    
    public var wrappedValue: Float {
        didSet {
            wrappedValue = min(1.0, max(0.0, wrappedValue))
        }
    }
    
    public init(wrappedValue: Float) {
        self.wrappedValue = min(1.0, max(0.0, wrappedValue))
    }
}

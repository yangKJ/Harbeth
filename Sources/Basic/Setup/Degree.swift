//
//  Degree.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

public struct Degree {
    
    public let value: Float
    
    public var radians: Float {
        return Float(value * Float.pi / 180.0)
    }
}

// MARK - Negative Degrees
public prefix func -(degree: Degree) -> Degree {
    return Degree(value: -1 * degree.value)
}

/// `0.0 ..< 360.0` 范围角度区间属性包装器
@propertyWrapper public struct DegreeRange {
    
    public var wrappedValue: Float {
        didSet {
            let value = wrappedValue.truncatingRemainder(dividingBy: 360.0)
            wrappedValue = value >= 0 ? value : 360 + value
        }
    }
    
    public init(wrappedValue: Float) {
        let value = wrappedValue.truncatingRemainder(dividingBy: 360.0)
        self.wrappedValue = value >= 0 ? value : 360 + value
    }
}

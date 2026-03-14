//
//  Degree.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

public struct Degree: Codable {
    
    public let value: Float
    
    public init(value: Float) {
        self.value = value
    }
    
    public var radians: Float {
        return Float(value * Float.pi / 180.0)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Float.self)
        self.value = min(360.0, max(0.0, value))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Negative Degrees
public prefix func -(degree: Degree) -> Degree {
    return Degree(value: -1 * degree.value)
}

/// `0.0 ..< 360.0` 范围角度区间属性包装器
@propertyWrapper public struct DegreeRange: Codable {
    
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Float.self)
        let normalizedValue = value.truncatingRemainder(dividingBy: 360.0)
        self.wrappedValue = normalizedValue >= 0 ? normalizedValue : 360 + normalizedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

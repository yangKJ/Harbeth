//
//  Clamping.swift
//  Harbeth
//
//  Created by Condy on 2023/1/8.
//

import Foundation

/// Range wrapper.
/// Example: ``@Clamping(0...2) var radius: Float = 1.0``
@propertyWrapper public struct Clamping<Value: Comparable & Codable>: Codable {
    private var value: Value
    private let range: ClosedRange<Value>
    
    public var wrappedValue: Value {
        get { value }
        set { value = Swift.min(Swift.max(newValue, range.lowerBound), range.upperBound) }
    }
    
    public init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.value = Swift.min(Swift.max(wrappedValue, range.lowerBound), range.upperBound)
        self.range = range
    }
    
    private enum CodingKeys: String, CodingKey {
        case value
        case range
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Value.self, forKey: .value)
        let range = try container.decode(ClosedRange<Value>.self, forKey: .range)
        self.init(wrappedValue: value, range)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(range, forKey: .range)
    }
}

//
//  Clamping.swift
//  Harbeth
//
//  Created by Condy on 2023/1/8.
//

import Foundation

/// Range wrapper.
/// Example: ``@Clamping(0...2) var radius: Float = 1.0``
@propertyWrapper public struct Clamping<Value: Comparable> {
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
}

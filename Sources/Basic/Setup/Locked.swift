//
//  Locked.swift
//  Harbeth
//
//  Created by Condy on 2023/3/8.
//

import Foundation

/// Define an atomic property decorator through Property Wrappers.
@propertyWrapper public final class Locked<Value> {
    
    private var value: Value
    //@available(iOS 10.0, OSX 10.12, watchOS 3.0, tvOS 10.0, *)
    private var unfairLock = os_unfair_lock_s()
    
    public init(wrappedValue value: Value) {
        self.value = value
    }
    
    public var wrappedValue: Value {
        get { return load() }
        set { store(newValue: newValue) }
    }
    
    private func load() -> Value {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return value
    }
    
    private func store(newValue: Value) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        value = newValue
    }
    
    private func withValue(_ closure: (Value) -> Value) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        value = closure(value)
    }
}

extension Locked where Value: Equatable {
    
    public static func == (left: Locked, right: Value) -> Bool {
        return left.wrappedValue == right
    }
}

extension Locked where Value: Comparable {
    
    public static func < (left: Locked, right: Value) -> Bool {
        return left.wrappedValue < right
    }
    
    public static func > (left: Locked, right: Value) -> Bool {
        return left.wrappedValue > right
    }
}

extension Locked where Value == Int {
    
    static func += (left: Locked, right: Value) {
        left.withValue { (value) -> Value in
            return value + right
        }
    }
    
    static func -= (left: Locked, right: Value) {
        left.withValue { (value) -> Value in
            return value - right
        }
    }
    
    static prefix func ++ (atomic: Locked) -> Value {
        var newValue: Value = 0
        atomic.withValue { (value) -> Value in
            newValue = value + 1
            return newValue
        }
        return newValue
    }
}

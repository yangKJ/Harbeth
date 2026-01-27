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
    
    public func modify(_ closure: (inout Value) -> Void) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        closure(&value)
    }
    
    public func withValue<T>(_ closure: (Value) -> T) -> T {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return closure(value)
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
        left.modify { $0 += right }
    }
    
    static func -= (left: Locked, right: Value) {
        left.modify { $0 -= right }
    }
    
    static prefix func ++ (atomic: Locked) -> Value {
        return atomic.withValue { value in
            atomic.modify { $0 += 1 }
            return value + 1
        }
    }
    
    static postfix func ++ (atomic: Locked) -> Value {
        return atomic.withValue { value in
            atomic.modify { $0 += 1 }
            return value
        }
    }
}

extension Locked where Value: RangeReplaceableCollection {
    public func append(_ element: Value.Element) {
        modify { $0.append(element) }
    }
    
    public func append(contentsOf elements: [Value.Element]) {
        modify { $0.append(contentsOf: elements) }
    }
    
    public func removeAll() {
        modify { $0.removeAll() }
    }
}

extension Locked where Value == [String: Any] {
    public func setValue(_ value: Any, forKey key: String) {
        modify { $0[key] = value }
    }
    
    public func value(forKey key: String) -> Any? {
        return withValue { $0[key] }
    }
}

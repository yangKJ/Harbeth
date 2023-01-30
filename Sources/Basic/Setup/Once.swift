//
//  Once.swift
//  Depth
//
//  Created by Condy on 2023/1/16.
//

import Foundation
import Darwin

public final class Once {
    private var lock = os_unfair_lock()
    private var hasRun = false
    private var value: Any?

    /// Executes the given closure only once. (Thread-safe)
    /// Example:
    ///
    ///     func process(_ text: String) -> String {
    ///         return text
    ///     }
    ///     let once = Once()
    ///     let a = once.run { process("a") }
    ///     let b = once.run { process("b") }
    ///     print(a, b) // => "a a"
    /// - Parameter closure: Returns the value that the called closure.
    /// - Returns: Returns the value that the called closure returns the first (and only) time it's called.
    public func run<T>(_ closure: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&lock)
        defer {
            os_unfair_lock_unlock(&lock)
        }
        guard !hasRun else {
            return value as! T
        }
        hasRun = true
        let returnValue = try closure()
        value = returnValue
        return returnValue
    }
    
    /// Wraps an optional single-argument function.
    public func wrap<T, U>(_ function: ((T) -> U)?) -> ((T) -> U)? {
        guard let function else {
            return nil
        }
        return { [self] parameter in
            run {
                function(parameter)
            }
        }
    }
}

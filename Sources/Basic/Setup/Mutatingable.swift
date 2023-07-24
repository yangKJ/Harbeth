//
//  Mutatingable.swift
//  Harbeth
//
//  Created by Condy on 2023/5/20.
//

import Foundation

/// Simply modify the `struct` attribute.
/// Used:
///
///     self.mutating(type: C7Crop.self) {
///         // do something..
///         $0.origin = .zero
///     }
public protocol Mutatingable {
    
    /// Modify the struct type value.
    /// - Parameters:
    ///   - type: Type of paradigm.
    ///   - block: Modify the callback.
    /// - Returns: Reture Self.
    @discardableResult func mutating<T>(type: T.Type, block: (inout T) -> Void) -> T
}

extension Mutatingable {
    
    @discardableResult public func mutating<T>(type: T.Type, block: (inout T) -> Void) -> T {
        var cc: T = self as! T
        block(&cc)
        return cc
    }
}

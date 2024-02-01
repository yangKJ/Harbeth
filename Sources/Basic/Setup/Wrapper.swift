//
//  Wrapper.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation

/// Add the `c7` prefix namespace.
public struct HarbethWrapper<Base> {
    /// Stores the type or meta-type of any extended type.
    public private(set) var base: Base
    /// Create an instance from the provided value.
    public init(base: Base) {
        self.base = base
    }
}

/// Protocol describing the `c7` extension points for Alamofire extended types.
public protocol HarbethCompatible { }

extension HarbethCompatible {
    
    public var c7: HarbethWrapper<Self> {
        get { return HarbethWrapper(base: self) }
        set { }
    }
    
    public static var c7: HarbethWrapper<Self>.Type {
        HarbethWrapper<Self>.self
    }
}

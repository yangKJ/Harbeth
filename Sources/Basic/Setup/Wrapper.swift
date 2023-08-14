//
//  Wrapper.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation

/// Add the `c7` prefix namespace
public struct Queen<Base> {
    public let base: Base
}

public protocol C7Compatible { }

extension C7Compatible {
    
    public var c7: Queen<Self> {
        get { return Queen(base: self) }
        set { }
    }
    
    public static var c7: Queen<Self>.Type {
        Queen<Self>.self
    }
}

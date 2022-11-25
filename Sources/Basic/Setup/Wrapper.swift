//
//  Wrapper.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation

/// Add the `mt` prefix namespace
public struct Queen<Base> {
    public let base: Base
}

public protocol C7Compatible { }

extension C7Compatible {
    public var mt: Queen<Self> {
        get { return Queen(base: self) }
        set { }
    }
    public static var mt: Queen<Self>.Type {
        Queen<Self>.self
    }
}

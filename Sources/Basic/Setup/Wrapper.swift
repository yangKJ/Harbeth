//
//  Wrapper.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import UIKit

/// Add the `mt` prefix namespace
public struct Queen<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

public protocol C7Compatible { }

extension C7Compatible {
    public var mt: Queen<Self> {
        get { return Queen(self) }
        set { }
    }
    public static var mt: Queen<Self>.Type {
        Queen<Self>.self
    }
}

extension C7Color: C7Compatible { }
extension CGFloat: C7Compatible { }
extension Double: C7Compatible { }
extension Float: C7Compatible { }
extension Int: C7Compatible { }

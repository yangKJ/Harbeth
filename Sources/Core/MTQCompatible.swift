//
//  MTQCompatible.swift
//  MetalQueenDemo
//
//  Created by 77。 on 2022/2/10.
//

import Foundation
import MetalKit
import UIKit

public typealias MTQImage = UIImage

/// 添加 `mt` 前缀命名空间
public struct Queen<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

public protocol MTQCompatible { }

extension MTQCompatible {
    public var mt: Queen<Self> {
        get { return Queen(self) }
        set { }
    }
    public static var mt: Queen<Self>.Type {
        Queen<Self>.self
    }
}

extension MTQImage: MTQCompatible { }

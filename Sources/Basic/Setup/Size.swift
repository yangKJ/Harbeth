//
//  Size.swift
//  Harbeth
//
//  Created by Condy on 2022/10/12.
//

import Foundation

public struct C7Size {
    
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

extension C7Size: Convertible {
    public func toFloatArray() -> [Float] {
        [Float(width), Float(height)]
    }
}

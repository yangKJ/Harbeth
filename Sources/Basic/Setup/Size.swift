//
//  Size.swift
//  Harbeth
//
//  Created by Condy on 2022/10/12.
//

import Foundation

public struct C7Size {
    
    public static let zero = C7Size(width: 0, height: 0)
    
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

extension C7Size: Equatable {
    
    public static func == (lhs: C7Size, rhs: C7Size) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
    }
}

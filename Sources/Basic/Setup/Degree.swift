//
//  Degree.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

public struct Degree {
    
    public let value: Float
    
    public var radians: Float {
        return Float(value * Float.pi / 180.0)
    }
}

// MARK - Negative Degrees
public prefix func -(degree: Degree) -> Degree {
    return Degree(value: -1 * degree.value)
}

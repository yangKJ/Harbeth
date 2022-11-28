//
//  Point2D.swift
//  Harbeth
//
//  Created by Condy on 2022/10/12.
//

import Foundation

/// 对于 2D 纹理，采用归一化之后的纹理坐标, 在 x 轴和 y 轴方向上都是从 0.0 到 1.0
/// 2D textures, normalized texture coordinates are used, from 0.0 to 1.0 in both x and y directions
public struct C7Point2D {
    
    public static let maximum = C7Point2D(x: 1.0, y: 1.0)
    public static let center  = C7Point2D(x: 0.5, y: 0.5)
    public static let zero    = C7Point2D(x: 0.0, y: 0.0)
    
    @ZeroOneRange public var x: Float
    @ZeroOneRange public var y: Float
    
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

extension C7Point2D: Convertible {
    public func toFloatArray() -> [Float] {
        [x, y]
    }
}

extension C7Point2D: Equatable {
    
    public static func == (lhs: C7Point2D, rhs: C7Point2D) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }
}

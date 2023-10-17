//
//  CGRect+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation

extension CGRect: HarbethCompatible { }

extension HarbethWrapper where Base == CGRect {
    
    public func radius(_ value: Float, max: Float) -> Float {
        let base = Float(sqrt(pow(base.width, 2) + pow(base.height, 2)))
        return base / 20 * value / max
    }
    
    public func toPoint2D(with size: C7Size) -> C7Point2D {
        C7Point2D(x: Float(base.origin.x) / Float(size.width),
                  y: Float(base.origin.y) / Float(size.height))
    }
}

//
//  CGPoint+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/11.
//

import Foundation
import CoreGraphics
import simd

extension CGPoint: C7Compatible { }

extension Queen where Base == CGPoint {
    
    public func middle(with point: CGPoint) -> CGPoint {
        return CGPoint(x: (base.x + point.x) * 0.5, y: (base.y + point.y) * 0.5)
    }
    
    public func distance(to other: CGPoint) -> CGFloat {
        let p = pow(base.x - other.x, 2) + pow(base.y - other.y, 2)
        return sqrt(p)
    }
    
    public func angle(to other: CGPoint = .zero) -> CGFloat {
        let point = CGPoint(x: base.x - other.x, y: base.y - other.y)
        if base.y == 0 {
            return base.x >= 0 ? 0 : CGFloat.pi
        }
        return -CGFloat(atan2f(Float(point.y), Float(point.x)))
    }
    
    public func to_vector_float4(z: CGFloat = 0, w: CGFloat = 1) -> vector_float4 {
        return [Float(base.x), Float(base.y), Float(z) ,Float(w)]
    }
    
    public func to_vector_float2() -> vector_float2 {
        return [Float(base.x), Float(base.y)]
    }
    
    public func offsetedBy(x: CGFloat = 0, y: CGFloat = 0) -> CGPoint {
        var point = base
        point.x += x
        point.y += y
        return point
    }
    
    public func rotatedBy(_ angle: CGFloat, anchor: CGPoint) -> CGPoint {
        let point = CGPoint(x: base.x - anchor.x, y: base.y - anchor.y)
        let a = Double(-angle)
        let x = Double(point.x)
        let y = Double(point.y)
        let x_ = x * cos(a) - y * sin(a)
        let y_ = x * sin(a) + y * cos(a)
        return CGPoint(x: x_ + anchor.x, y: y_ + anchor.y)
    }
}

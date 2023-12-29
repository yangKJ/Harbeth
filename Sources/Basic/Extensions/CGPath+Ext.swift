//
//  CGPath+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/12/18.
//

import Foundation
import CoreGraphics

extension CGPath: HarbethCompatible { }

extension HarbethWrapper where Base: CGPath {
    
    public var isClosed: Bool {
        var isClosed = false
        base.c7.forEach { element in
            if element.type == .closeSubpath {
                isClosed = true
            }
        }
        return isClosed
    }
    
    public var points: [CGPoint] {
        var arrayPoints: [CGPoint] = [CGPoint]()
        base.c7.forEach { element in
            switch (element.type) {
            case CGPathElementType.moveToPoint:
                arrayPoints.append(element.points[0])
            case .addLineToPoint:
                arrayPoints.append(element.points[0])
            case .addQuadCurveToPoint:
                arrayPoints.append(element.points[0])
                arrayPoints.append(element.points[1])
            case .addCurveToPoint:
                arrayPoints.append(element.points[0])
                arrayPoints.append(element.points[1])
                arrayPoints.append(element.points[2])
            default:
                break
            }
        }
        return arrayPoints
    }
    
    public func forEach(body: @escaping @convention(block) (CGPathElement) -> Void) {
        typealias Body = @convention(block) (CGPathElement) -> Void
        let callback: @convention(c) (UnsafeMutableRawPointer, UnsafePointer<CGPathElement>) -> Void = { (info, element) in
            let body = unsafeBitCast(info, to: Body.self)
            body(element.pointee)
        }
        let unsafeBody = unsafeBitCast(body, to: UnsafeMutableRawPointer.self)
        base.apply(info: unsafeBody, function: unsafeBitCast(callback, to: CGPathApplierFunction.self))
    }
}

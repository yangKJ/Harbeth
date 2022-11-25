//
//  CATransform3D+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import QuartzCore

extension CATransform3D: C7Compatible { }

extension Queen where Base == CATransform3D {
    
    public enum Axis { case x, y, z }
    
    public static var identity: CATransform3D {
        return CATransform3DIdentity
    }
    
    // MARK: - Rotate and Translation
    
    public func rotate(_ axis: Axis, by degree: Degree) -> CATransform3D {
        let radians = CGFloat(degree.radians)
        switch axis {
        case .x:
            return CATransform3DRotate(base, radians, 1, 0, 0)
        case .y:
            return CATransform3DRotate(base, radians, 0, 1, 0)
        case .z:
            return CATransform3DRotate(base, radians, 0, 0, 1)
        }
    }
    
    public func scale(_ axis: Axis, by scale: CGFloat) -> CATransform3D {
        switch axis {
        case .x:
            return CATransform3DScale(base, scale, 1, 1)
        case .y:
            return CATransform3DScale(base, 1, scale, 1)
        case .z:
            return CATransform3DScale(base, 1, 1, scale)
        }
    }
    
    public func translate(_ axis: Axis, by value: CGFloat) -> CATransform3D {
        switch axis {
        case .x:
            return CATransform3DTranslate(base, value, 0, 0)
        case .y:
            return CATransform3DTranslate(base, 0, value, 0)
        case .z:
            return CATransform3DTranslate(base, 0, 0, value)
        }
    }
    
    public func perspective(_ m34: CGFloat = -1.0 / 500) -> CATransform3D {
        var transform = base
        transform.m34 = m34
        return transform
    }
}

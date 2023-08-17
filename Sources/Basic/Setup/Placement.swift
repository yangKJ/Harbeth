//
//  Placement.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import simd

public enum Placement {
    /// Not scale the content.
    case fixed
    /// True to change image size to fit image size.
    case fit
    //case full
    //case stretch
}

extension Placement {
    
    public func rotate(angle: Float, size: C7Size) -> C7Size {
        switch self {
        case .fixed:
            return size
        case .fit:
            let w = Int(abs(sin(angle) * Float(size.height)) + abs(cos(angle) * Float(size.width)))
            let h = Int(abs(sin(angle) * Float(size.width)) + abs(cos(angle) * Float(size.height)))
            return C7Size(width: w, height: h)
        }
    }
    
    public func resize(width: Float, height: Float, size: C7Size) -> C7Size {
        switch self {
        case .fixed:
            return size
        case .fit:
            let w = width > 0 ? Int(width) : size.width
            let h = height > 0 ? Int(height) : size.height
            return C7Size(width: w, height: h)
        }
    }
    
    public func transform(_ transform: CGAffineTransform, size: C7Size) -> C7Size {
        switch self {
        case .fixed:
            return size
        case .fit:
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height).applying(transform)
            return rect.size.c7.toC7Size()
        }
    }
}

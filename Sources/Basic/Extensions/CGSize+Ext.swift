//
//  CGSize+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import CoreGraphics

extension CGSize: C7Compatible { }

extension Queen where Base == CGSize {
    
    public func toC7Size() -> C7Size {
        C7Size(width: Int(base.width), height: Int(base.height))
    }
    
    /// Returns a size by resizing the `base` size by making it aspect fitting the given `size`.
    ///
    /// - Parameter size: The size in which the `base` should fit in.
    /// - Returns: The size fitted in by the input `size`, while keeps `base` aspect.
    public func constrained(_ size: CGSize) -> CGSize {
        let aspectWidth = round(aspectRatio * size.height)
        let aspectHeight = round(size.width / aspectRatio)
        let width  = aspectWidth > size.width ? size.width : aspectWidth
        let height = aspectWidth > size.width ? aspectHeight : size.height
        return CGSize(width: width, height: height)
    }
    
    /// Returns a size by resizing the `base` size by making it aspect filling the given `size`.
    ///
    /// - Parameter size: The size in which the `base` should fill.
    /// - Returns: The size be filled by the input `size`, while keeps `base` aspect.
    public func filling(_ size: CGSize) -> CGSize {
        let aspectWidth = round(aspectRatio * size.height)
        let aspectHeight = round(size.width / aspectRatio)
        let width  = aspectWidth < size.width ? size.width : aspectWidth
        let height = aspectWidth < size.width ? aspectHeight : size.height
        return CGSize(width: width, height: height)
    }
    
    private var aspectRatio: CGFloat {
        return base.height == 0.0 ? 1.0 : base.width / base.height
    }
    
    /// Returns a `CGRect` for which the `base` size is constrained to an input `size` at a given `anchor` point.
    ///
    /// - Parameters:
    ///   - size: The size in which the `base` should be constrained to.
    ///   - anchor: An anchor point in which the size constraint should happen.
    /// - Returns: The result `CGRect` for the constraint operation.
    public func constrainedRect(for size: CGSize, anchor: CGPoint) -> CGRect {
        let unifiedAnchor = CGPoint(x: anchor.x.mt_clamped(to: 0.0...1.0), y: anchor.y.mt_clamped(to: 0.0...1.0))
        let x = unifiedAnchor.x * base.width - unifiedAnchor.x * size.width
        let y = unifiedAnchor.y * base.height - unifiedAnchor.y * size.height
        let r = CGRect(x: x, y: y, width: size.width, height: size.height)
        let origin = CGRect(origin: .zero, size: base)
        return origin.intersection(r)
    }
}

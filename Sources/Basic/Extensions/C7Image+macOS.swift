//
//  C7Image+macOS.swift
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

import Foundation

#if os(macOS)
import AppKit

// https://developer.apple.com/documentation/appkit/nsimage

extension C7Image {
    
    public convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }
    
    public var cgImage: CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    
    public var scale: CGFloat {
        return 1.0
    }
}

extension Queen where Base: C7Image {
    
    public var size: CGSize {
        return base.representations.reduce(.zero) { (size, rep) in
            let width  = max(size.width, CGFloat(rep.pixelsWide))
            let height = max(size.height, CGFloat(rep.pixelsHigh))
            return CGSize(width: width, height: height)
        }
    }
    
    /// Flip image, Need to be used in `base.lockFocus()`
    ///
    /// Example:
    ///
    ///     image.lockFocus()
    ///     image.mt.flip(horizontal: true, vertical: true)
    ///
    /// - Parameters:
    ///   - horizontal: Flip 180 degrees from left to right or right to left.
    ///   - vertical: Flip 180 degrees from top down or bottom up.
    public func flip(horizontal: Bool = true, vertical: Bool = true) {
        if horizontal == false && vertical == false { return }
        var tx = base.size.width
        var ty = base.size.height
        var sx: CGFloat = -1
        var sy: CGFloat = -1
        if horizontal, !vertical {
            tx = 0; sx = 1
        } else if !horizontal, vertical {
            ty = 0; sy = 1
        }
        let transform = NSAffineTransform.init(transform: .identity)
        transform.translateX(by: tx, yBy: ty)
        transform.scaleX(by: sx, yBy: sy)
        transform.concat()
    }
}
#endif

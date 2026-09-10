//
//  C7View+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/12/18.
//

import Foundation

extension C7View: HarbethCompatible { }

#if os(iOS) || os(tvOS)
import UIKit

// https://developer.apple.com/documentation/uikit/uiview

extension HarbethWrapper where Base: C7View {

    @MainActor
    public func toImage() -> C7Image {
        if let scroll = base as? UIScrollView {
            return UIGraphicsImageRenderer(size: scroll.bounds.size).image(actions: { _ in
                let bounds_ = scroll.bounds.offsetBy(dx: -scroll.contentOffset.x, dy: -scroll.contentOffset.y)
                scroll.drawHierarchy(in: bounds_, afterScreenUpdates: true)
            })
        }
        return UIGraphicsImageRenderer(size: base.bounds.size).image(actions: { _ in
            base.drawHierarchy(in: base.bounds, afterScreenUpdates: true)
        })
    }
    
    @MainActor
    public func toImage(bezierPath: UIBezierPath) -> C7Image {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = base.traitCollection.displayScale
        format.opaque = false
        return UIGraphicsImageRenderer(size: base.bounds.size, format: format).image { context in
            context.cgContext.saveGState()
            bezierPath.addClip()
            base.drawHierarchy(in: base.bounds, afterScreenUpdates: true)
            context.cgContext.restoreGState()
        }
    }
}

#endif

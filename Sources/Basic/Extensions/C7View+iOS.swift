//
//  C7View+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/12/18.
//

import Foundation

extension C7View: HarbethCompatible { }

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

// https://developer.apple.com/documentation/uikit/uiview

extension HarbethWrapper where Base: C7View {
    
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
    
    public func toImage(bezierPath: UIBezierPath) -> C7Image {
        let maskLayer = CAShapeLayer.init()
        maskLayer.path = bezierPath.cgPath
        maskLayer.fillColor = UIColor.black.cgColor
        maskLayer.strokeColor = UIColor.darkGray.cgColor
        maskLayer.frame = base.bounds
        maskLayer.contentsCenter = .init(x: 0.5, y: 0.5, width: 0.1, height: 0.1)
        maskLayer.contentsScale = UIScreen.main.scale
        
        let contentLayer = CALayer.init()
        contentLayer.mask = maskLayer
        contentLayer.frame = base.bounds
        base.layer.mask = maskLayer
        
        return base.c7.toImage()
    }
}

#endif

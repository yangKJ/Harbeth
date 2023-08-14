//
//  CGRect+Ext.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation

extension CGRect: C7Compatible { }

extension Queen where Base == CGRect {
    
    public func radius(_ value: Float, max: Float) -> Float {
        let base = Float(sqrt(pow(base.width, 2) + pow(base.height, 2)))
        return base / 20 * value / max
    }
}

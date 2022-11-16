//
//  Comparable+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

extension Comparable {
    
    public func mt_clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
    
    public func mt_between(min: Self, max: Self) -> Self {
        if self > max {
            return max
        } else if self < min {
            return min
        }
        return self
    }
}

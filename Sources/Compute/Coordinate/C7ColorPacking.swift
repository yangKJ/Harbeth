//
//  C7ColorPacking.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// 色彩丢失/模糊效果
public struct C7ColorPacking: C7FilterProtocol {
    
    /// The larger the transverse offset, the more the green contour shadow offset to the right.
    /// The texel width and height determines how far out to sample from this texel.
    public var horizontalTexel: Float
    /// The larger the vertical offset, the more the blue contour shadow offset downward.
    public var verticalTexel: Float
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorPacking")
    }
    
    public var factors: [Float] {
        return [horizontalTexel, verticalTexel]
    }
    
    public init(horizontalTexel: Float = 0, verticalTexel: Float = 0) {
        self.horizontalTexel = horizontalTexel
        self.verticalTexel = verticalTexel
    }
}

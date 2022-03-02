//
//  C7BilateralBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

/// 双边模糊
public struct C7BilateralBlur: C7FilterProtocol {
    
    public var blurRadius: Float = 1
    public var offect: C7Point2D = C7Point2DCenter
    
    public var modifier: Modifier {
        return .compute(kernel: "C7BilateralBlur")
    }
    
    public var factors: [Float] {
        return [blurRadius, offect.x, offect.y]
    }
    
    public init() { }
}

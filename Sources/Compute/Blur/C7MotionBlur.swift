//
//  C7MotionBlur.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

/// 移动模糊
public struct C7MotionBlur: C7FilterProtocol {
    
    /// A multiplier for the blur size
    public var blurSize: Float = 0
    /// The angular direction of the blur, in degrees, with a default of 0.0
    public var blurAngle: Float = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7MotionBlur")
    }
    
    public var factors: [Float] {
        return [blurSize, blurAngle]
    }
    
    public init(blurSize: Float = 0, blurAngle: Float = 0) {
        self.blurSize = blurSize
        self.blurAngle = blurAngle
    }
}

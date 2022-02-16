//
//  C7Rotate.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Rotate: C7FilterProtocol {
    
    /// Angle to rotate, unit is degree
    public var angle: Float {
        get { return _angle / Float.pi * 180 }
        set { _angle = newValue * Float.pi / 180 }
    }
    /// True to change image size to fit rotated image, false to keep image size
    public var fitSize: Bool = true
    
    private var _angle: Float = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Rotate")
    }
    
    public var factors: [Float] {
        return [_angle]
    }
    
    public func outputSize(input size: C7Size) -> C7Size {
        if fitSize {
            let w = Int(abs(sin(_angle) * Float(size.height)) + abs(cos(_angle) * Float(size.width)))
            let h = Int(abs(sin(_angle) * Float(size.width)) + abs(cos(_angle) * Float(size.height)))
            return (width: w, height: h)
        }
        return size
    }
    
    public init() {
        self.angle = 0
    }
}

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
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Rotate")
    }
    
    public var factors: [Float] {
        return [_angle]
    }
    
    public func outputSize(input size: C7Size) -> C7Size {
        return mode.rotate(angle: _angle, size: size)
    }
    
    private var _angle: Float = 0
    private var mode: ShapeMode = .fitSize
    
    public init(mode: ShapeMode = .fitSize, angle: Float = 0) {
        self.angle = angle
        self.mode = mode
    }
}

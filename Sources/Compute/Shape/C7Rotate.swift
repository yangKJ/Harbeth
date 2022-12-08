//
//  C7Rotate.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Rotate: C7FilterProtocol {
    
    /// Angle to rotate, unit is degree
    @DegreeRange public var angle: Float
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Rotate")
    }
    
    public var factors: [Float] {
        return [Degree(value: angle).radians]
    }
    
    public func resize(input size: C7Size) -> C7Size {
        return mode.rotate(angle: Degree(value: angle).radians, size: size)
    }
    
    private var mode: ShapeMode = .fitSize
    
    public init(mode: ShapeMode = .fitSize, angle: Float = 0) {
        self.angle = angle
        self.mode = mode
    }
}

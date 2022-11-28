//
//  C7Hue.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation

public struct C7Hue: C7FilterProtocol {
    
    /// Hue adjustment, unit is degree
    @DegreeRange public var hue: Float = 90.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Hue")
    }
    
    public var factors: [Float] {
        return [Degree(value: hue).radians]
    }
    
    public init(hue: Float = 90.0) {
        self.hue = hue
    }
}

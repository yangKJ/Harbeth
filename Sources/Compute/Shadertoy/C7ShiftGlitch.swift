//
//  C7ShiftGlitch.swift
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

import Foundation

/// RGB Shift Glitch
public struct C7ShiftGlitch: C7FilterProtocol {
    
    /// The adjusted time, from 0.0 to 1.0, with a default of 0.5
    public var time: Float = 0.5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ShiftGlitch")
    }
    
    public var factors: [Float] {
        return [time]
    }
    
    public init(time: Float = 0.5) {
        self.time = time
    }
}

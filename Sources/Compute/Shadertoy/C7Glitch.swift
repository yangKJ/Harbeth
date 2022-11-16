//
//  C7Glitch.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

import Foundation

public struct C7Glitch: C7FilterProtocol {
    
    /// The adjusted glitch, from 0.0 to 1.0, with a default of 0.5
    public var glitch: Float = 0.5
    public var maxJitter: Float = 0.06
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Glitch")
    }
    
    public var factors: [Float] {
        return [glitch, maxJitter]
    }
    
    public init(glitch: Float = 0.5, maxJitter: Float = 0.06) {
        self.glitch = glitch
        self.maxJitter = maxJitter
    }
}

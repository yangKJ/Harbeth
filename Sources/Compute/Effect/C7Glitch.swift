//
//  C7Glitch.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

import Foundation

public struct C7Glitch: C7FilterProtocol {
    
    /// The adjusted progress, from 0.0 to 1.0, with a default of 0.5
    public var progress: Float = 0.5
    public var maxJitter: Float = 0.06
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Glitch")
    }
    
    public var factors: [Float] {
        return [progress, maxJitter]
    }
    
    public init() { }
}

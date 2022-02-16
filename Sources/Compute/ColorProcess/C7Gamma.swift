//
//  C7Gamma.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Gamma: C7FilterProtocol {
    
    /// The adjusted gamma, from 0 to 3.0, with a default of 1.0
    public var gamma: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Gamma")
    }
    
    public var factors: [Float] {
        return [gamma]
    }
    
    public init() { }
}

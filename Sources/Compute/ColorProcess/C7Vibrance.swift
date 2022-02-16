//
//  C7Vibrance.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Vibrance: C7FilterProtocol {
    
    /// Change the vibrance of an image, from -1.2 to 1.2, with a default of 0.0
    public var vibrance: Float = 0.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Vibrance")
    }
    
    public var factors: [Float] {
        return [vibrance]
    }
    
    public init() { }
}

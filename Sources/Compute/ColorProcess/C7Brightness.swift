//
//  C7Brightness.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Foundation

public struct C7Brightness: C7FilterProtocol {
    
    public let minBrightness: Float = -1.0
    public let maxBrightness: Float = 1.0
    
    /// The adjusted brightness, from -1.0 to 1.0, with a default of 0.0 being the original picture.
    public var brightness: Float = 0.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Brightness")
    }
    
    public var factors: [Float] {
        return [brightness]
    }
    
    public init() { }
}

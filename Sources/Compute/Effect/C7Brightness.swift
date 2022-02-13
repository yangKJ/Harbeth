//
//  C7Brightness.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Foundation

public struct C7Brightness: C7FilterProtocol {
    
    public private(set) var minBrightness: Float = -1.0
    public private(set) var maxBrightness: Float = 1.0
    
    public var brightness: Float = 0.0
    
    public var modifier: Modifier {
        return .compute(kernel: "Brightness")
    }
    
    public var factors: [Float] {
        return [brightness]
    }
    
    public init(brightness: Float = 0.0) {
        self.brightness = brightness
    }
}

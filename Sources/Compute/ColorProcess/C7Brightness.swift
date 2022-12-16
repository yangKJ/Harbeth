//
//  C7Brightness.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Foundation

/// 亮度
public struct C7Brightness: C7FilterProtocol {
    
    /// The adjusted brightness, from -1.0 to 1.0, with a default of 0.0 being the original picture.
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    public var brightness: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Brightness")
    }
    
    public var factors: [Float] {
        return [brightness]
    }
    
    public init(brightness: Float = range.value) {
        self.brightness = brightness
    }
}

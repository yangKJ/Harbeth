//
//  C7GaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

public struct C7GaussianBlur: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    /// Sets the radius of the blur.
    public var radius: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7GaussianBlur")
    }
    
    public var factors: [Float] {
        return [radius]
    }
    
    public init(radius: Float = range.value) {
        self.radius = radius
    }
}

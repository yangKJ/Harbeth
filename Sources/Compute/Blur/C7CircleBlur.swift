//
//  C7CircleBlur.swift
//  Harbeth
//
//  Created by Condy on 2023/8/17.
//

import Foundation

// See: https://www.imgonline.com.ua/eng/blur-angular.php
// https://support.apple.com/en-in/guide/motion/motn169f953e/mac
public struct C7CircleBlur: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    /// Sets the radius of the circle defining the blurred area. You can also drag the onscreen controls in the canvas.
    public var radius: Float = range.value
    
    /// Sets the amount of the blur.
    public var amount: Int = 20
    
    public var modifier: Modifier {
        return .compute(kernel: "C7CircleBlur")
    }
    
    public var factors: [Float] {
        return [radius, Float(amount)]
    }
    
    public init(radius: Float = range.value, amount: Int = 20) {
        self.radius = radius
        self.amount = amount
    }
}

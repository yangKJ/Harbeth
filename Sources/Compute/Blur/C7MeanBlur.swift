//
//  C7MeanBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

/// 均值模糊效果
/// https://docs.gimp.org/2.10/en/gimp-filter-median-blur.html
public struct C7MeanBlur: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    /// The radius of the neighborhood. Increasing radius increases blur.
    /// Contrary to the “Gaussian” filter, edges are not blurred. Corners are rounded and convex surfaces are eroded.
    public var radius: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7MeanBlur")
    }
    
    public var factors: [Float] {
        return [radius]
    }
    
    public init(radius: Float = range.value) {
        self.radius = radius
    }
}

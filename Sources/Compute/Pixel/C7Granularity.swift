//
//  C7Granularity.swift
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

import Foundation

/// 调节胶片颗粒感
public struct C7Granularity: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 0.5, value: 0.3)
    
    /// The grain size is adjusted by adjusting the grain parameter. The grain size ranges from 0.0 to 0.5,
    /// Where 0.0 represents the original image,
    public var grain: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Granularity")
    }
    
    public var factors: [Float] {
        return [grain]
    }
    
    public init(grain: Float = range.value) {
        self.grain = grain
    }
}

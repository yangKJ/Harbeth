//
//  C7Exposure.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

/// 曝光效果
/// See: https://docs.unity3d.com/cn/Packages/com.unity.render-pipelines.high-definition@10.4/manual/Override-Exposure.html
public struct C7Exposure: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -10.0, max: 10.0, value: 0.0)
    
    /// The adjusted exposure, from -10.0 to 10.0, with a default of 0.0
    public var exposure: Float = range.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Exposure")
    }
    
    public var factors: [Float] {
        return [exposure]
    }
    
    public init(exposure: Float = range.value) {
        self.exposure = exposure
    }
}

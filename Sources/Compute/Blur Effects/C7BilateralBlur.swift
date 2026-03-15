//
//  C7BilateralBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

/// 双边模糊
/// A bilateral blur, which tries to blur similar color values while preserving sharp edges
public struct C7BilateralBlur: C7FilterProtocol {
    
    /// 空间域标准差，控制模糊范围，默认值为15.0
    /// Spatial domain standard deviation, control fuzzy range
    public var sigmaSpace: Float = 15.0
    
    /// 颜色域标准差，控制颜色相似性阈值，默认值为0.3
    /// Color domain standard deviation, control color similarity threshold
    public var sigmaColor: Float = 0.3
    
    /// 模糊半径，控制采样范围，默认值为7
    /// Fuzzy radius, control sampling range
    public var radius: Float = 7
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7BilateralBlur")
    }
    
    public var factors: [Float] {
        return [sigmaSpace, sigmaColor, radius]
    }
    
    public init(sigmaSpace: Float = 15.0, sigmaColor: Float = 0.3, radius: Float = 7) {
        self.sigmaSpace = sigmaSpace
        self.sigmaColor = sigmaColor
        self.radius = radius
    }
    
    public init(radius: Float = 7) {
        self.init(sigmaSpace: 15.0, sigmaColor: 0.3, radius: radius)
    }
}

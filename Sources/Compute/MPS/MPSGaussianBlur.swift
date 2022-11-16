//
//  MPSGaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/10/14.
//

import Foundation
import MetalPerformanceShaders

/// 高斯模糊
public struct MPSGaussianBlur: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    /// The radius determines how many pixels are used to create the blur.
    public var radius: Float = range.value {
        didSet {
            self.gaussian = MPSImageGaussianBlur(device: Device.device(), sigma: radius)
        }
    }
    
    public var modifier: Modifier {
        return .mps(performance: self.gaussian)
    }
    
    private var gaussian: MPSImageGaussianBlur
    
    public init(radius: Float = range.value) {
        self.gaussian = MPSImageGaussianBlur(device: Device.device(), sigma: radius)
    }
}

//
//  MPSGaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/10/14.
//

import Foundation
import MetalPerformanceShaders

public struct MPSGaussianBlur: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    public var radius: Float = range.value {
        didSet {
            self.gaussian = MPSImageGaussianBlur(device: Device.device(), sigma: radius)
        }
    }
    
    public var modifier: Modifier {
        return .mps(performance: self.gaussian)
    }
    
    private var gaussian: MPSImageGaussianBlur
    
    public init() {
        self.gaussian = MPSImageGaussianBlur(device: Device.device(), sigma: radius)
    }
}

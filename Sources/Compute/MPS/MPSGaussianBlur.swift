//
//  MPSGaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/10/14.
//

import Foundation
import MetalPerformanceShaders

public struct MPSGaussianBlur: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, MPSGaussianBlur> = .init(min: 0, max: 100)
    
    public var radius: Float = 1 {
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

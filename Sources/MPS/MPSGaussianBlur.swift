//
//  MPSGaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/10/14.
//

import Foundation
import MetalPerformanceShaders

/// 高斯模糊
public struct MPSGaussianBlur: C7FilterProtocol, MPSKernelProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    /// The radius determines how many pixels are used to create the blur.
    @Clamping(range.min...range.max) public var radius: Float = range.value {
        didSet {
            self.gaussian = MPSImageGaussianBlur(device: Device.device(), sigma: ceil(radius))
        }
    }
    
    public var modifier: Modifier {
        return .mps(performance: self.gaussian)
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destinationTexture = textures[0]
        let sourceTexture = textures[1]
        self.gaussian.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destinationTexture)
        return destinationTexture
    }
    
    private var gaussian: MPSImageGaussianBlur
    
    public init(radius: Float = range.value) {
        self.gaussian = MPSImageGaussianBlur(device: Device.device(), sigma: ceil(radius))
    }
}

//
//  MPSCanny.swift
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

import Foundation
import MetalPerformanceShaders

/// Canny边缘检测
@available(iOS 14.0, macOS 11.0, *)
public struct MPSCanny: MPSKernelProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 1, value: 0.1)
    
    /// 低阈值
    @Clamping(range.min...range.max) public var lowThreshold: Float = range.value {
        didSet {
            self.canny = MPSImageCanny(device: Device.device(), linearToGrayScaleTransform: &lowThreshold, sigma: highThreshold)
            self.canny.edgeMode = .clamp
        }
    }
    
    /// 高阈值
    @Clamping(range.min...range.max) public var highThreshold: Float = range.value * 3 {
        didSet {
            self.canny = MPSImageCanny(device: Device.device(), linearToGrayScaleTransform: &lowThreshold, sigma: highThreshold)
            self.canny.edgeMode = .clamp
        }
    }
    
    public var modifier: ModifierEnum {
        return .mps(performance: self.canny)
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destTexture = textures[0], sourceTexture = textures[1]
        self.canny.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destTexture)
        return destTexture
    }
    
    private var canny: MPSImageCanny
    
    public init(lowThreshold: Float = range.value, highThreshold: Float = range.value * 3) {
        var threshold = lowThreshold
        self.canny = MPSImageCanny(device: Device.device(), linearToGrayScaleTransform: &threshold, sigma: highThreshold)
        self.canny.edgeMode = .clamp
        self.lowThreshold = lowThreshold
        self.highThreshold = highThreshold
    }
}

//
//  MPSMedian.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation
import MetalPerformanceShaders

/// 中值滤波，有效去除椒盐噪声
/// Median filtering can effectively remove salt and pepper noise.
public struct MPSMedian: MPSKernelProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 1, max: 25, value: 3)
    
    /// Filter radius, control processing range.
    @Clamping(range.min...range.max) public var radius: Float = range.value {
        didSet {
            let kernelWidth = Int(ceil(radius) * 2 + 1)
            self.median = MPSImageMedian(device: Device.device(), kernelDiameter: kernelWidth)
        }
    }
    
    public var modifier: ModifierEnum {
        return .mps(performance: self.median)
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destTexture = textures[0], sourceTexture = textures[1]
        self.median.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destTexture)
        return destTexture
    }
    
    private var median: MPSImageMedian {
        didSet {
            median.edgeMode = .clamp
        }
    }
    
    public init(radius: Float = range.value) {
        let kernelWidth = Int(ceil(radius) * 2 + 1)
        self.median = MPSImageMedian(device: Device.device(), kernelDiameter: kernelWidth)
    }
}

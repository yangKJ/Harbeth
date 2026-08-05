//
//  MPSGaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/10/14.
//

import Foundation
import MetalPerformanceShaders

/// 高斯模糊
public struct MPSGaussianBlur: MPSKernelProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    /// The radius determines how many pixels are used to create the blur.
    @Clamping(range.min...range.max) public var radius: Float = range.value {
        didSet {
            self.gaussian = MPSImageGaussianBlur(device: HarbethContext.shared.device, sigma: ceil(radius))
        }
    }
    
    public var modifier: ModifierEnum {
        return .mps(performance: self.gaussian)
    }

    /// MPS 内部会把高斯分布截断为有限采样核。这里使用大于常见截断范围的
    /// `4 * sigma` 作为保守 halo，供 HugeImage 等区域执行器安全规划 tile。
    public var samplingFootprint: SamplingFootprint {
        .neighborhood(radius: Self.conservativeHaloRadius(for: radius))
    }

    public var kernelPixelContract: KernelPixelContract {
        .init(samplingFootprint: samplingFootprint)
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destTexture = textures[0], sourceTexture = textures[1]
        self.gaussian.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destTexture)
        return destTexture
    }
    
    private var gaussian: MPSImageGaussianBlur {
        didSet {
            gaussian.edgeMode = .clamp
        }
    }
    
    public init(radius: Float = range.value) {
        self.gaussian = MPSImageGaussianBlur(device: HarbethContext.shared.device, sigma: ceil(radius))
        self.gaussian.edgeMode = .clamp
        self.radius = radius
    }

    public static func conservativeHaloRadius(for radius: Float) -> Int {
        guard radius.isFinite, radius > 0 else { return 0 }
        return Int(ceil(radius)) * 4
    }
}

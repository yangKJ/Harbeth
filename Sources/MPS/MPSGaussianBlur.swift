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
    
    /// radius入口保留向上取整；sigma入口直接使用像素标准差。
    @Clamping(range.min...range.max) public var radius: Float = range.value {
        didSet {
            self.gaussian = MPSImageGaussianBlur(device: HarbethContext.shared.device, sigma: sigma)
        }
    }
    
    public let edgeMode: MPSImageEdgeMode

    public var sigma: Float {
        usesExactSigma ? radius : ceil(radius)
    }

    public var factors: [Float] {
        [sigma, Float(edgeMode.rawValue)]
    }

    public var modifier: ModifierEnum {
        return .mps(performance: self.gaussian)
    }

    /// MPS 内部会把高斯分布截断为有限采样核。这里使用大于常见截断范围的
    /// `4 * sigma` 作为保守 halo，供 HugeImage 等区域执行器安全规划 tile。
    public var samplingFootprint: SamplingFootprint {
        .neighborhood(radius: Self.conservativeHaloRadius(forSigma: sigma))
    }

    public var kernelPixelContract: KernelPixelContract {
        .init(samplingFootprint: samplingFootprint)
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destTexture = textures[0], sourceTexture = textures[1]
        self.gaussian.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destTexture)
        return destTexture
    }
    
    private let usesExactSigma: Bool

    private var gaussian: MPSImageGaussianBlur {
        didSet {
            gaussian.edgeMode = edgeMode
        }
    }
    
    public init(radius: Float = range.value, edgeMode: MPSImageEdgeMode = .clamp) {
        self.usesExactSigma = false
        self.edgeMode = edgeMode
        self.gaussian = MPSImageGaussianBlur(device: HarbethContext.shared.device, sigma: ceil(radius))
        self.gaussian.edgeMode = edgeMode
        self.radius = radius
    }

    public init(sigma: Float, edgeMode: MPSImageEdgeMode = .clamp) throws {
        guard sigma.isFinite, sigma > 0, sigma <= Self.range.max else {
            throw HarbethError.filterParameterInvalid("MPSGaussianBlur的sigma必须为(0,100]内的有限值。")
        }
        self.usesExactSigma = true
        self.edgeMode = edgeMode
        self.gaussian = MPSImageGaussianBlur(device: HarbethContext.shared.device, sigma: sigma)
        self.gaussian.edgeMode = edgeMode
        self.radius = sigma
    }

    public static func conservativeHaloRadius(forSigma sigma: Float) -> Int {
        guard sigma.isFinite, sigma > 0, sigma <= Self.range.max else { return 0 }
        return Int(ceil(sigma * 4))
    }

    public static func conservativeHaloRadius(for radius: Float) -> Int {
        guard radius.isFinite, radius > 0 else { return 0 }
        return Int(ceil(radius)) * 4
    }
}

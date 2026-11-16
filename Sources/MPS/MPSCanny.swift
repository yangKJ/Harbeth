//
//  MPSCanny.swift
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

import Foundation
import MetalPerformanceShaders

/// Canny边缘检测
@available(iOS 14.0, macOS 11.0, tvOS 14.0, *)
public struct MPSCanny: MPSKernelProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 1, value: 0.1)
    
    /// 低阈值
    @Clamping(range.min...range.max)
    public var lowThreshold: Float = range.value
    
    /// 高阈值
    @Clamping(range.min...range.max)
    public var highThreshold: Float = range.value * 3

    /// MPSImageCanny 的灰度变换始终是独立的 RGB 三元组；阈值和 sigma 不复用这块内存。
    public let linearToGrayScaleTransform: SIMD3<Float>

    /// MPS 内核对象是引用类型。每次按值构造独立实例，避免 struct 复制后共享可变阈值状态。
    private func makeCanny() -> MPSImageCanny {
        var transform = [linearToGrayScaleTransform.x, linearToGrayScaleTransform.y, linearToGrayScaleTransform.z]
        let kernel = transform.withUnsafeMutableBufferPointer { values in
            MPSImageCanny(
                device: HarbethContext.shared.device,
                linearToGrayScaleTransform: values.baseAddress!,
                sigma: sigma
            )
        }
        let low = lowThreshold.isFinite ? lowThreshold : Self.range.value
        let high = highThreshold.isFinite ? highThreshold : Self.range.value * 3
        kernel.lowThreshold = min(low, high)
        kernel.highThreshold = max(low, high)
        kernel.edgeMode = .clamp
        kernel.useFastMode = false
        return kernel
    }

    /// sigma 是高斯预平滑参数，不再错误地取自 highThreshold。
    public let sigma: Float
    
    public var factors: [Float] {
        [lowThreshold, highThreshold, sigma, linearToGrayScaleTransform.x, linearToGrayScaleTransform.y, linearToGrayScaleTransform.z]
    }

    public var samplingFootprint: SamplingFootprint { .global }

    public var modifier: ModifierEnum {
        return .mps(performance: makeCanny())
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destTexture = textures[0], sourceTexture = textures[1]
        makeCanny().encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destTexture)
        return destTexture
    }
    
    public init(
        lowThreshold: Float = range.value,
        highThreshold: Float = range.value * 3,
        sigma: Float = 1.4142135,
        linearToGrayScaleTransform: SIMD3<Float> = SIMD3(0.299, 0.587, 0.114)
    ) {
        self.lowThreshold = min(lowThreshold, highThreshold)
        self.highThreshold = max(lowThreshold, highThreshold)
        self.sigma = sigma.isFinite && sigma > 0 ? sigma : 1.4142135
        self.linearToGrayScaleTransform = [linearToGrayScaleTransform.x, linearToGrayScaleTransform.y, linearToGrayScaleTransform.z].allSatisfy(\.isFinite) ? linearToGrayScaleTransform : SIMD3(0.299, 0.587, 0.114)
    }
}

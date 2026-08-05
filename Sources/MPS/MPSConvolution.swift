//
//  MPSConvolution.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation
import MetalPerformanceShaders

/// 通用 MPS 卷积原子。
///
/// 卷积核尺寸必须为正奇数，权重以 row-major 顺序传入。输出尺寸保持与输入一致，
/// 并要求调用方提供独立的目标纹理。
public struct MPSConvolution: MPSKernelProtocol {

    public static let maximumKernelDimension = 63

    public let kernelWidth: Int
    public let kernelHeight: Int
    public let weights: [Float]
    public let bias: Float
    public let edgeMode: MPSImageEdgeMode

    public var modifier: ModifierEnum {
        .mps(performance: convolution)
    }

    public var factors: [Float] {
        [Float(kernelWidth), Float(kernelHeight), bias, Float(edgeMode.rawValue)] + weights
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var samplingFootprint: SamplingFootprint {
        .neighborhood(radius: max(kernelWidth, kernelHeight) / 2)
    }

    public var kernelPixelContract: KernelPixelContract {
        .init(samplingFootprint: samplingFootprint)
    }

    public init(kernelWidth: Int,
                kernelHeight: Int,
                weights: [Float],
                bias: Float = 0,
                edgeMode: MPSImageEdgeMode = .clamp) throws {
        try Self.validate(
            kernelWidth: kernelWidth,
            kernelHeight: kernelHeight,
            weights: weights,
            bias: bias
        )

        self.kernelWidth = kernelWidth
        self.kernelHeight = kernelHeight
        self.weights = weights
        self.bias = bias
        self.edgeMode = edgeMode
        self.convolution = weights.withUnsafeBufferPointer { buffer in
            MPSImageConvolution(
                device: HarbethContext.shared.device,
                kernelWidth: kernelWidth,
                kernelHeight: kernelHeight,
                weights: buffer.baseAddress!
            )
        }
        self.convolution.bias = bias
        self.convolution.edgeMode = edgeMode
    }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let (destination, source) = try mpsTexturePair(from: textures)
        guard destination.width == source.width, destination.height == source.height else {
            throw HarbethError.textureSizeMismatch
        }
        convolution.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        return destination
    }

    static func validate(kernelWidth: Int,
                         kernelHeight: Int,
                         weights: [Float],
                         bias: Float) throws {
        guard (1...maximumKernelDimension).contains(kernelWidth), kernelWidth.isMultiple(of: 2) == false else {
            throw HarbethError.filterParameterInvalid(
                "MPSConvolution kernelWidth must be an odd number within 1...\(maximumKernelDimension)."
            )
        }
        guard (1...maximumKernelDimension).contains(kernelHeight), kernelHeight.isMultiple(of: 2) == false else {
            throw HarbethError.filterParameterInvalid(
                "MPSConvolution kernelHeight must be an odd number within 1...\(maximumKernelDimension)."
            )
        }
        guard weights.count == kernelWidth * kernelHeight else {
            throw HarbethError.filterParameterInvalid("MPSConvolution weights count must equal kernelWidth * kernelHeight.")
        }
        guard weights.allSatisfy(\.isFinite) else {
            throw HarbethError.filterParameterInvalid("MPSConvolution weights must be finite.")
        }
        guard bias.isFinite else {
            throw HarbethError.filterParameterInvalid("MPSConvolution bias must be finite.")
        }
    }

    private let convolution: MPSImageConvolution
}

func mpsTexturePair(from textures: [MTLTexture]) throws -> (destination: MTLTexture, source: MTLTexture) {
    guard textures.count >= 2 else {
        throw HarbethError.filterParameterInvalid("MPS kernels require destination and source textures.")
    }
    let destination = textures[0]
    let source = textures[1]
    guard destination !== source else {
        throw HarbethError.filterParameterInvalid("MPS kernels require distinct source and destination textures.")
    }
    return (destination, source)
}

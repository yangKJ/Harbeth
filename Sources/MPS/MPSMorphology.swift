//
//  MPSMorphology.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation
import MetalPerformanceShaders

/// 基于 MPS 的矩形形态学原子。
///
/// 内部使用全零 probe，因此与 MPS 的 area max/min 行为一致。kernel 统一收敛到
/// `1...9` 的奇数，保持与现有 mask morphology 的边界一致。
public struct MPSMorphology: MPSKernelProtocol {

    public enum Operation: Sendable {
        case dilate
        case erode
    }

    public static let kernelSizeRange = 1...9

    public let operation: Operation
    public let kernelSize: Int

    public var modifier: ModifierEnum {
        .mps(performance: morphology)
    }

    public var factors: [Float] {
        [operation == .dilate ? 1 : 0, Float(kernelSize)]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var samplingFootprint: SamplingFootprint {
        .neighborhood(radius: kernelSize / 2)
    }

    public var kernelPixelContract: KernelPixelContract {
        .init(samplingFootprint: samplingFootprint)
    }

    public init(operation: Operation, kernelSize: Int = 3) {
        let normalizedKernelSize = Self.normalize(kernelSize)
        self.operation = operation
        self.kernelSize = normalizedKernelSize
        let values = [Float](repeating: 0, count: normalizedKernelSize * normalizedKernelSize)
        self.morphology = values.withUnsafeBufferPointer { buffer in
            switch operation {
            case .dilate:
                MPSImageDilate(
                    device: HarbethContext.shared.device,
                    kernelWidth: normalizedKernelSize,
                    kernelHeight: normalizedKernelSize,
                    values: buffer.baseAddress!
                )
            case .erode:
                MPSImageErode(
                    device: HarbethContext.shared.device,
                    kernelWidth: normalizedKernelSize,
                    kernelHeight: normalizedKernelSize,
                    values: buffer.baseAddress!
                )
            }
        }
    }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let (destination, source) = try mpsTexturePair(from: textures)
        guard destination.width == source.width, destination.height == source.height else {
            throw HarbethError.textureSizeMismatch
        }
        morphology.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        return destination
    }

    static func normalize(_ value: Int) -> Int {
        let clamped = min(max(value, kernelSizeRange.lowerBound), kernelSizeRange.upperBound)
        return clamped.isMultiple(of: 2) ? min(clamped + 1, kernelSizeRange.upperBound) : clamped
    }

    private let morphology: MPSUnaryImageKernel
}

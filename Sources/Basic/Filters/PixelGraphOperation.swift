//
//  PixelGraphOperation.swift
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

import CoreGraphics
import Metal
import simd

/// Numeric RGBA operations. Inputs and outputs use the same premultiplied representation.
public struct PixelGraphOperation: C7FilterProtocol {
    public enum Operation: Int { case matrix, clamp, maskRed, maskAlpha, multiply, unpremultiply, opaque, interpolate, preserveAlpha, constant }
    public let operation: Operation
    public let background: MTLTexture
    public let mask: MTLTexture
    public let rows: [SIMD4<Float>]
    public let bias: SIMD4<Float>
    public let maximum: SIMD4<Float>

    public init(_ operation: Operation, background: MTLTexture, mask: MTLTexture? = nil,
                rows: [SIMD4<Float>] = [], bias: SIMD4<Float> = .zero, maximum: SIMD4<Float> = .one) {
        self.operation = operation
        self.background = background
        self.mask = mask ?? background
        self.rows = rows.count == 4 ? rows : [SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, 0, 0, 1)]
        self.bias = bias
        self.maximum = maximum
    }

    public func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        guard [background, mask].allSatisfy({ $0.width == texture.width && $0.height == texture.height }) else {
            throw HarbethError.textureSizeMismatch
        }
        return texture
    }
    public var modifier: ModifierEnum { .compute(kernel: "PixelGraphOperation") }
    public var otherInputTextures: C7InputTextures { [background, mask] }
    public var memoryAccessPattern: MemoryAccessPattern { .multiTexture }
    public var kernelParameterBindings: [KernelParameterBinding] {
        [KernelParameterBinding(name: "operation", index: 0, stage: .compute, value: .int(operation.rawValue))]
        + rows.enumerated().map { KernelParameterBinding(name: "row\($0.offset)", index: $0.offset + 1, stage: .compute, value: .float4($0.element)) }
        + [KernelParameterBinding(name: "bias", index: 5, stage: .compute, value: .float4(bias)),
           KernelParameterBinding(name: "maximum", index: 6, stage: .compute, value: .float4(maximum))]
    }
}

/// Samples a finite source region using an inverse projective mapping in pixel coordinates.
public struct ImageRegionTransform: C7FilterProtocol {
    public let sourceRegion: CGRect
    public let outputRegion: CGRect
    public let inverse: simd_float3x3
    public let edgeClamped: Bool
    public let outputSize: CGSize?

    public init(sourceRegion: CGRect, outputRegion: CGRect, inverse: simd_float3x3, edgeClamped: Bool = false, outputSize: CGSize? = nil) {
        self.sourceRegion = sourceRegion
        self.outputRegion = outputRegion
        self.inverse = inverse
        self.edgeClamped = edgeClamped
        self.outputSize = outputSize
    }
    public func resize(input size: C7Size) -> C7Size { outputSize.map { C7Size(width: Int($0.width), height: Int($0.height)) } ?? size }
    public var modifier: ModifierEnum { .compute(kernel: "ImageRegionTransform") }
    public var kernelParameterBindings: [KernelParameterBinding] {
        let rows = (0..<3).map { SIMD4<Float>(inverse[0][$0], inverse[1][$0], inverse[2][$0], 0) }
        return [KernelParameterBinding(name: "sourceRegion", index: 0, stage: .compute, value: .float4(SIMD4(Float(sourceRegion.minX), Float(sourceRegion.minY), Float(sourceRegion.width), Float(sourceRegion.height)))),
                KernelParameterBinding(name: "outputRegion", index: 1, stage: .compute, value: .float4(SIMD4(Float(outputRegion.minX), Float(outputRegion.minY), Float(outputRegion.width), Float(outputRegion.height))))]
            + rows.enumerated().map { KernelParameterBinding(name: "row\($0.offset)", index: $0.offset + 2, stage: .compute, value: .float4($0.element)) }
            + [KernelParameterBinding(name: "clamped", index: 5, stage: .compute, value: .bool(edgeClamped))]
    }
}

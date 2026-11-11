//
//  TextureReductions.swift
//  Harbeth
//
//  Created by Condy on 2026/11/11.
//

import Foundation
import Metal

/// RGB histograms weighted by source alpha and optional red-channel coverage.
/// Values are unpremultiplied in the texture's storage domain and clamped to 0...1.
public struct WeightedColorHistogram: Sendable, Equatable {
    public let channels: [[Double]]

    /// The first row is the mean of the three RGB histograms, not luminance.
    public var meanAndRGB: [[Double]] {
        let mean = (0..<256).map { (channels[0][$0] + channels[1][$0] + channels[2][$0]) / 3 }
        return [mean] + channels
    }
}

public extension MTLTextureCompatible_ {
    /// Reads back block histograms rather than source pixels. Floating-point accumulation
    /// may differ from a serial Double sum; callers should compare normalized bins with tolerance.
    func makeWeightedColorHistogram(
        coverage: MTLTexture? = nil,
        region: MTLRegion? = nil,
        maximumReadbackBytes: Int = 16 * 1024 * 1024
    ) throws -> WeightedColorHistogram {
        let texture = target
        try TextureReductionBackend.validate(texture)
        let region = region ?? MTLRegionMake2D(0, 0, texture.width, texture.height)
        guard region.origin.x >= 0, region.origin.y >= 0, region.origin.z == 0,
              region.size.width > 0, region.size.height > 0, region.size.depth == 1,
              region.origin.x <= texture.width - region.size.width,
              region.origin.y <= texture.height - region.size.height else {
            throw HarbethError.configurationInvalid("Histogram region must be inside the source texture.")
        }
        if let coverage {
            try TextureReductionBackend.validate(coverage)
            guard coverage.device === texture.device, coverage.width == texture.width, coverage.height == texture.height else {
                throw HarbethError.configurationInvalid("Coverage must match the source device and dimensions.")
            }
        }
        let blocksX = (region.size.width + 31) / 32
        let blocksY = (region.size.height + 31) / 32
        let valueCount = blocksX * blocksY * 768
        let resultBytes = valueCount * MemoryLayout<Float>.stride + MemoryLayout<UInt32>.stride
        guard resultBytes <= maximumReadbackBytes else {
            throw HarbethError.configurationInvalid("Histogram reduction exceeds its readback budget.")
        }
        var parameters = [UInt32(region.origin.x), UInt32(region.origin.y), UInt32(region.size.width),
                          UInt32(region.size.height), UInt32(blocksX), coverage == nil ? 0 : 1]
        let buffer = try TextureReductionBackend.run(
            texture: texture,
            coverage: coverage,
            kernel: "WeightedColorHistogramBlocks",
            parameters: &parameters,
            resultBytes: resultBytes,
            groups: MTLSize(width: blocksX, height: blocksY, depth: 1),
            threads: MTLSize(width: 256, height: 1, depth: 1)
        )
        let invalid = buffer.contents().advanced(by: valueCount * MemoryLayout<Float>.stride).load(as: UInt32.self)
        guard invalid == 0 else { throw HarbethError.configurationInvalid("Histogram input contains non-finite values.") }
        let values = buffer.contents().bindMemory(to: Float.self, capacity: valueCount)
        var channels = Array(repeating: Array(repeating: 0.0, count: 256), count: 3)
        for block in 0..<(blocksX * blocksY) {
            for channel in 0..<3 {
                for bin in 0..<256 {
                    channels[channel][bin] += Double(values[block * 768 + channel * 256 + bin])
                }
            }
        }
        return WeightedColorHistogram(channels: channels)
    }

    /// Finds every finite positive alpha, including binary16 subnormals. RGB values are ignored.
    /// Only compact block bounds are read back; the source is never copied to CPU memory.
    func alphaCoverageBounds(maximumReadbackBytes: Int = 16 * 1024 * 1024) throws -> MaskCoverageBounds? {
        let texture = target
        try TextureReductionBackend.validate(texture, allowsSRGB: true)
        let blocksX = (texture.width + 15) / 16
        let blocksY = (texture.height + 15) / 16
        let valueCount = 6
        let byteCount = valueCount * MemoryLayout<UInt32>.stride
        guard byteCount <= maximumReadbackBytes else {
            throw HarbethError.configurationInvalid("Alpha reduction exceeds its readback budget.")
        }
        var parameters = [UInt32(texture.width), UInt32(texture.height), UInt32(blocksX)]
        let buffer = try TextureReductionBackend.run(
            texture: texture,
            coverage: nil,
            kernel: "TextureAlphaBoundsBlocks",
            parameters: &parameters,
            resultBytes: byteCount,
            groups: MTLSize(width: blocksX, height: blocksY, depth: 1),
            threads: MTLSize(width: 1, height: 1, depth: 1),
            initialValues: [UInt32(texture.width), UInt32(texture.height), 0, 0, 0, 0]
        )
        let values = buffer.contents().bindMemory(to: UInt32.self, capacity: valueCount)
        guard values[5] == 0 else { throw HarbethError.configurationInvalid("Alpha contains non-finite values.") }
        guard values[4] != 0 else { return nil }
        let left = Int(values[0]), top = Int(values[1]), right = Int(values[2]), bottom = Int(values[3])
        return MaskCoverageBounds(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }
}

private enum TextureReductionBackend {
    static func validate(_ texture: MTLTexture, allowsSRGB: Bool = false) throws {
        let formats: [MTLPixelFormat] = [.rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float]
        let srgb = allowsSRGB && [.rgba8Unorm_srgb, .bgra8Unorm_srgb].contains(texture.pixelFormat)
        guard texture.device === HarbethContext.shared.device, texture.textureType == .type2D,
              texture.arrayLength == 1, texture.sampleCount == 1, texture.storageMode != .memoryless,
              texture.width > 0, texture.height > 0, formats.contains(texture.pixelFormat) || srgb else {
            throw HarbethError.configurationInvalid("Reduction requires a readable RGBA texture on the active device.")
        }
        try Task.checkCancellation()
    }

    static func run(
        texture: MTLTexture,
        coverage: MTLTexture?,
        kernel: String,
        parameters: inout [UInt32],
        resultBytes: Int,
        groups: MTLSize,
        threads: MTLSize,
        initialValues: [UInt32] = []
    ) throws -> MTLBuffer {
        let pipeline = try Compute.makeComputePipelineState(with: kernel)
        guard let buffer = texture.device.makeBuffer(length: resultBytes, options: .storageModeShared),
              let command = HarbethContext.shared.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        memset(buffer.contents(), 0, resultBytes)
        if !initialValues.isEmpty {
            initialValues.withUnsafeBytes { buffer.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(coverage ?? texture, index: 1)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.setBytes(&parameters, length: parameters.count * MemoryLayout<UInt32>.stride, index: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        try command.commitAndWaitUntilCompleted(identifier: kernel)
        HarbethContext.shared.recycleCommandBuffer(command)
        try Task.checkCancellation()
        return buffer
    }
}

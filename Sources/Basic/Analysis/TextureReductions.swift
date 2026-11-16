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
        // 中间直方图按条带复用，CPU 只读取最终 768 个 bin 和错误标志。
        let resultBytes = 769 * MemoryLayout<Float>.stride
        guard resultBytes <= maximumReadbackBytes else {
            throw HarbethError.configurationInvalid("Histogram reduction exceeds its readback budget.")
        }
        let blocksX = (region.size.width + 31) / 32
        let stripeRows = max(1, 1024 / blocksX) * 32
        let maximumBlocks = blocksX * ((min(stripeRows, region.size.height) + 31) / 32)
        let partialBytes = (maximumBlocks * 768 + 1) * MemoryLayout<Float>.stride
        guard let partials = texture.device.makeBuffer(length: partialBytes, options: .storageModePrivate),
              let result = texture.device.makeBuffer(length: resultBytes, options: .storageModeShared),
              let command = HarbethContext.shared.makeCommandBuffer() else { throw HarbethError.commandBuffer }
        defer { HarbethContext.shared.recycleCommandBuffer(command) }
        memset(result.contents(), 0, resultBytes)
        #if targetEnvironment(simulator)
        let kernel = "WeightedColorHistogramBlocks"
        #else
        let supportsSIMD = texture.device.supportsFamily(.apple7) || texture.device.supportsFamily(.mac2)
        let kernel = supportsSIMD ? "WeightedColorHistogramSIMDBlocks" : "WeightedColorHistogramBlocks"
        #endif
        let blockPipeline = try Compute.makeComputePipelineState(with: kernel)
        let finalPipeline = try Compute.makeComputePipelineState(with: "WeightedColorHistogramFinalize")
        for startY in stride(from: 0, to: region.size.height, by: stripeRows) {
            try Task.checkCancellation()
            let rows = min(stripeRows, region.size.height - startY)
            let blocksY = (rows + 31) / 32
            var parameters = [UInt32(region.origin.x), UInt32(region.origin.y + startY), UInt32(region.size.width),
                              UInt32(rows), UInt32(blocksX), coverage == nil ? 0 : 1]
            guard let clear = command.makeBlitCommandEncoder() else { throw HarbethError.commandBuffer }
            clear.fill(buffer: partials, range: 0..<partialBytes, value: 0)
            clear.endEncoding()
            guard let encoder = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
            encoder.setComputePipelineState(blockPipeline)
            encoder.setTexture(texture, index: 0)
            encoder.setTexture(coverage ?? texture, index: 1)
            encoder.setBuffer(partials, offset: 0, index: 0)
            encoder.setBytes(&parameters, length: parameters.count * 4, index: 1)
            encoder.dispatchThreadgroups(MTLSize(width: blocksX, height: blocksY, depth: 1),
                                         threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
            encoder.endEncoding()
            guard let final = command.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
            var count = UInt32(blocksX * blocksY)
            final.setComputePipelineState(finalPipeline)
            final.setBuffer(partials, offset: 0, index: 0)
            final.setBuffer(result, offset: 0, index: 1)
            final.setBytes(&count, length: 4, index: 2)
            final.dispatchThreads(MTLSize(width: 768, height: 1, depth: 1),
                                  threadsPerThreadgroup: MTLSize(width: min(256, finalPipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1))
            final.endEncoding()
        }
        try command.commitAndWaitUntilCompleted(identifier: "WeightedHistogram")
        try Task.checkCancellation()
        let values = result.contents().bindMemory(to: Float.self, capacity: 769)
        guard values[768].bitPattern == 0 else { throw HarbethError.configurationInvalid("Histogram input contains non-finite values.") }
        let channels = (0..<3).map { channel in (0..<256).map { Double(values[channel * 256 + $0]) } }
        return WeightedColorHistogram(channels: channels)
    }

    /// Finds every finite positive alpha, including binary16 subnormals. RGB values are ignored.
    /// Small inputs use bounded CPU readback when the budget permits; shared inputs avoid GPU submission.
    /// Larger inputs use a fixed 24-byte GPU summary. Producers must complete their writes before inspection.
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
        let bytesPerPixel = texture.pixelFormat == .rgba16Float ? 8 : (texture.pixelFormat == .rgba32Float ? 16 : 4)
        let sourceBytes = texture.width * texture.height * bytesPerPixel
        let cpuPixelLimit = texture.storageMode == .shared ? 256 * 256 : 64 * 64
        if texture.width * texture.height <= cpuPixelLimit, sourceBytes <= maximumReadbackBytes {
            return try TextureReductionBackend.alphaBoundsCPU(texture, bytesPerPixel: bytesPerPixel, maximumBytes: sourceBytes)
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

    static func alphaBoundsCPU(_ texture: MTLTexture, bytesPerPixel: Int, maximumBytes: Int) throws -> MaskCoverageBounds? {
        guard let data = texture.c7.rawBytes(maximumBytes: maximumBytes) else { throw HarbethError.source2Texture }
        var left = texture.width, top = texture.height, right = -1, bottom = -1
        try data.withUnsafeBytes { raw in
            for y in 0..<texture.height {
                if y.isMultiple(of: 32) { try Task.checkCancellation() }
                for x in 0..<texture.width {
                    let offset = (y * texture.width + x) * bytesPerPixel
                    let visible: Bool
                    if bytesPerPixel == 4 {
                        visible = raw[offset + 3] != 0
                    } else if bytesPerPixel == 8 {
                        let bits = UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: offset + 6, as: UInt16.self))
                        guard bits & 0x7C00 != 0x7C00 else { throw HarbethError.configurationInvalid("Alpha contains non-finite values.") }
                        visible = bits & 0x8000 == 0 && bits & 0x7FFF != 0
                    } else {
                        let bits = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: offset + 12, as: UInt32.self))
                        guard bits & 0x7F800000 != 0x7F800000 else { throw HarbethError.configurationInvalid("Alpha contains non-finite values.") }
                        visible = bits & 0x80000000 == 0 && bits & 0x7FFFFFFF != 0
                    }
                    if visible {
                        left = min(left, x)
                        top = min(top, y)
                        right = max(right, x)
                        bottom = max(bottom, y)
                    }
                }
            }
        }
        try Task.checkCancellation()
        return right >= left ? MaskCoverageBounds(x: left, y: top, width: right - left + 1, height: bottom - top + 1) : nil
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

//
//  MaskDistanceTransform.swift
//  Harbeth
//
//  Created by Condy on 2026/11/16.
//

import Metal
@preconcurrency import MetalPerformanceShaders

/// 使用同一个 command buffer 生成 mask 的 inside/outside 欧氏距离场。
/// 中间纹理由同一命令缓冲区引用，完成后才交付输出。
internal enum MaskDistanceTransformExecutor {
    static func execute(mask: MaskDescriptor, maxDistance: Float, threshold: Float, signed: Bool, outputFormat: MTLPixelFormat) throws -> MTLTexture {
        let device = mask.texture.device
        guard let commandBuffer = makeMaskCommandBuffer(for: device) else { throw HarbethError.commandBuffer }
        let coverage = try makeTexture(device: device, width: mask.texture.width, height: mask.texture.height,
            format: mask.texture.pixelFormat, label: "MaskDistanceTransform.coverage")
        _ = try MaskCoverageExtract(mask: mask).applyAtTexture(form: mask.texture, to: coverage, for: commandBuffer)
        let inside = try makeTexture(device: device, width: coverage.width, height: coverage.height, format: .r8Unorm, label: "MaskDistanceTransform.inside")
        let outside = try makeTexture(device: device, width: coverage.width, height: coverage.height, format: .r8Unorm, label: "MaskDistanceTransform.outside")
        let insideDistance = try makeTexture(device: device, width: coverage.width, height: coverage.height, format: .r16Float, label: "MaskDistanceTransform.insideDistance")
        let outsideDistance = try makeTexture(device: device, width: coverage.width, height: coverage.height, format: .r16Float, label: "MaskDistanceTransform.outsideDistance")
        let output = try makeTexture(device: device, width: coverage.width, height: coverage.height, format: outputFormat, label: "MaskDistanceTransform.output")
        guard let flags = device.makeBuffer(length: 2 * MemoryLayout<UInt32>.stride, options: .storageModePrivate) else { throw HarbethError.commandBuffer }
        guard let clear = commandBuffer.makeBlitCommandEncoder() else { throw HarbethError.makeBlitCommandEncoder }
        clear.fill(buffer: flags, range: 0..<flags.length, value: 0); clear.endEncoding()
        let pipeline = try Compute.makeComputePipelineState(with: "MaskDistanceBinary")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        var thresholdValue = threshold
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(inside, index: 0); encoder.setTexture(outside, index: 1); encoder.setTexture(coverage, index: 2); encoder.setBuffer(flags, offset: 0, index: 1)
        encoder.setBytes(&thresholdValue, length: MemoryLayout<Float>.stride, index: 0)
        encoder.dispatchThreads(MTLSize(width: coverage.width, height: coverage.height, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        encoder.endEncoding()
        let transform = MPSImageEuclideanDistanceTransform(device: device)
        if #available(macOS 11.0, iOS 14.0, tvOS 14.0, *) { transform.searchLimitRadius = maxDistance }
        transform.encode(commandBuffer: commandBuffer, sourceTexture: inside, destinationTexture: insideDistance)
        transform.encode(commandBuffer: commandBuffer, sourceTexture: outside, destinationTexture: outsideDistance)
        let combine = try Compute.makeComputePipelineState(with: signed ? "MaskDistanceSignedCombineMPS" : "MaskDistanceUnsignedCombine")
        guard let combineEncoder = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.commandBuffer }
        var distance = maxDistance
        combineEncoder.setComputePipelineState(combine)
        combineEncoder.setTexture(output, index: 0); combineEncoder.setTexture(insideDistance, index: 1); combineEncoder.setTexture(outsideDistance, index: 2)
        if !signed { combineEncoder.setTexture(inside, index: 3) }
        combineEncoder.setBuffer(flags, offset: 0, index: 1)
        combineEncoder.setBytes(&distance, length: MemoryLayout<Float>.stride, index: 0)
        combineEncoder.dispatchThreads(MTLSize(width: coverage.width, height: coverage.height, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        combineEncoder.endEncoding()
        commandBuffer.commit(); commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error { throw commandBuffer.error ?? HarbethError.commandBuffer }
        return output
    }

    private static func makeTexture(device: MTLDevice, width: Int, height: Int, format: MTLPixelFormat, label: String) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw HarbethError.makeTexture }
        texture.label = label
        return texture
    }
}

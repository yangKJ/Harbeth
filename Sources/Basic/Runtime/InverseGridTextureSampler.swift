//
//  InverseGridTextureSampler.swift
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

import Foundation
import Metal
import simd

/// Renders a source texture through a top-left-origin inverse coordinate grid.
public enum InverseGridTextureSampler {
    public static func render(
        source: MTLTexture,
        field: MTLTexture,
        sourceRegion: CGRect,
        sourceExtent: CGRect,
        outputRegion: CGRect,
        outputSize: CGSize,
        outputPixelFormat: MTLPixelFormat = .rgba16Float,
        outputExtent: CGRect? = nil,
        outputToField: simd_float3x3 = matrix_identity_float3x3,
        clipsGridBounds: Bool = false,
        commandBuffer suppliedCommandBuffer: MTLCommandBuffer? = nil
    ) throws -> MTLTexture {
        let resolvedOutputExtent = outputExtent ?? sourceExtent
        guard resolvedOutputExtent.width > 0, resolvedOutputExtent.height > 0,
              [outputToField[0], outputToField[1], outputToField[2]].allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
              source.device === HarbethContext.shared.device, field.device === source.device,
              sourceRegion.width > 0, sourceRegion.height > 0, sourceExtent.width > 0,
              sourceExtent.height > 0, outputRegion.width > 0, outputRegion.height > 0,
              outputSize.width.isFinite, outputSize.height.isFinite,
              outputSize.width > 0, outputSize.height > 0,
              outputSize.width.rounded() == outputSize.width, outputSize.height.rounded() == outputSize.height,
              source.textureType == .type2D, field.textureType == .type2D,
              source.sampleCount == 1, field.sampleCount == 1,
              outputSize.width <= 16384, outputSize.height <= 16384,
              [sourceRegion, sourceExtent, outputRegion, resolvedOutputExtent].allSatisfy({
                  $0.origin.x.isFinite && $0.origin.y.isFinite && $0.width.isFinite && $0.height.isFinite
              }) else {
            throw HarbethError.configurationInvalid("Inverse grid texture sampling requires finite, non-empty regions.")
        }
        try Task.checkCancellation()
        let width = Int(outputSize.width.rounded(.up))
        let height = Int(outputSize.height.rounded(.up))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: outputPixelFormat,
            width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let output = HarbethContext.shared.device.makeTexture(descriptor: descriptor) else { throw HarbethError.makeTexture }
        let pipeline = try Compute.makeComputePipelineState(with: "InverseGridTextureSampler")
        guard let commandBuffer = suppliedCommandBuffer ?? HarbethContext.shared.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.makeComputeCommandEncoder }
        struct Uniforms {
            var sourceRegion: SIMD4<Float>
            var sourceExtent: SIMD4<Float>
            var outputRegion: SIMD4<Float>
            var outputSize: SIMD2<Float>
            var outputExtent: SIMD4<Float>
            var row0: SIMD4<Float>
            var row1: SIMD4<Float>
            var row2: SIMD4<Float>
            var clipsGridBounds: UInt32
        }
        var uniforms = Uniforms(
            sourceRegion: SIMD4(Float(sourceRegion.minX), Float(sourceRegion.minY), Float(sourceRegion.width), Float(sourceRegion.height)),
            sourceExtent: SIMD4(Float(sourceExtent.minX), Float(sourceExtent.minY), Float(sourceExtent.width), Float(sourceExtent.height)),
            outputRegion: SIMD4(Float(outputRegion.minX), Float(outputRegion.minY), Float(outputRegion.width), Float(outputRegion.height)),
            outputSize: SIMD2(Float(outputSize.width), Float(outputSize.height)),
            outputExtent: SIMD4(Float((outputExtent ?? sourceExtent).minX), Float((outputExtent ?? sourceExtent).minY), Float((outputExtent ?? sourceExtent).width), Float((outputExtent ?? sourceExtent).height)),
            row0: SIMD4(outputToField[0][0], outputToField[1][0], outputToField[2][0], 0),
            row1: SIMD4(outputToField[0][1], outputToField[1][1], outputToField[2][1], 0),
            row2: SIMD4(outputToField[0][2], outputToField[1][2], outputToField[2][2], 0),
            clipsGridBounds: clipsGridBounds ? 1 : 0
        )
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(field, index: 1)
        encoder.setTexture(output, index: 2)
        encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        let w = pipeline.threadExecutionWidth
        let h = max(1, pipeline.maxTotalThreadsPerThreadgroup / w)
        encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1), threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1))
        encoder.endEncoding()
        if suppliedCommandBuffer == nil {
            try commandBuffer.commitAndWaitUntilCompleted(identifier: "InverseGridTextureSampler")
            HarbethContext.shared.recycleCommandBuffer(commandBuffer)
        }
        return output
    }
}

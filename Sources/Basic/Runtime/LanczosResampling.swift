// 由 Condy 创建于 2026/11/17。内置缩放的恒等与可分离执行，保持同名覆盖和直接回退。
import Foundation
import Metal

enum LanczosResampling {
    static var byteLimit: Int { min(64 * 1024 * 1024, HarbethContext.shared.texturePool.byteLimit / 4) }

    static func scratch(input: C7Size, output: C7Size, limit: Int) -> (size: C7Size, axis: UInt32, bytes: Int)? {
        guard input.width > 0, input.height > 0, output.width > 0, output.height > 0,
              output.width < input.width || output.height < input.height else { return nil }
        let a = output.width.multipliedReportingOverflow(by: input.height)
        let b = input.width.multipliedReportingOverflow(by: output.height)
        guard !a.overflow, !b.overflow, min(a.partialValue, b.partialValue) <= limit / 16 else { return nil }
        let horizontal = a.partialValue <= b.partialValue
        return (C7Size(width: horizontal ? output.width : input.width, height: horizontal ? input.height : output.height),
                horizontal ? 0 : 1, min(a.partialValue, b.partialValue) * 16)
    }

    static func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture], descriptor: KernelDescriptor,
                       maximumTemporaryBytes: Int? = nil) throws -> MTLTexture? {
        let identity = descriptor.functionIdentity
        guard textures.count == 2, ["C7Resize", "C7LanczosResize"].contains(identity.primaryName),
              identity.functionConstants.isEmpty, descriptor.parameterBindings.isEmpty,
              identity.librarySource == .harbethFramework || (identity.librarySource == .automatic && BuiltinKernelAdmission.isUnmodified([identity.primaryName])),
              textures.allSatisfy({ $0.textureType == .type2D && $0.arrayLength == 1 && $0.sampleCount == 1 }) else { return nil }
        let output = textures[0], input = textures[1]
        if input.width == output.width && input.height == output.height {
            // 跨格式仍由原缩放核量化，避免恒等优化引入额外转换内核依赖。
            guard input.pixelFormat == output.pixelFormat else { return nil }
            return try PipelineIdentityFilter().encode(commandBuffer: commandBuffer, textures: textures)
        }
        guard identity.primaryName == "C7LanczosResize",
              [.rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float].contains(input.pixelFormat),
              [.rgba8Unorm, .bgra8Unorm, .rgba16Float, .rgba32Float].contains(output.pixelFormat),
              let scratch = scratch(input: C7Size(texture: input), output: C7Size(texture: output), limit: maximumTemporaryBytes ?? byteLimit),
              let pipeline = try? HarbethContext.shared.makeComputePipelineState(identity: .init(kind: .compute, primaryName: "HarbethLanczosAxis", librarySource: .harbethFramework)),
              let lease = try? TextureLoader.makeTextureLease(width: scratch.size.width, height: scratch.size.height, options: [
                .texturePixelFormat: MTLPixelFormat.rgba32Float, .textureStorageMode: MTLStorageMode.private,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite]), .textureHazardTrackingMode: MTLHazardTrackingMode.tracked
              ], identifier: "LanczosResampling") else { return nil }
        // 失败前已编码的 pass 也持有租约；未提交时由 handler 的销毁归还。
        commandBuffer.addCompletedHandler { _ in lease.release() }
        for pass in 0..<2 {
            let source = pass == 0 ? input : lease.texture, destination = pass == 0 ? lease.texture : output
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.makeComputeCommandEncoder }
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(destination, index: 0); encoder.setTexture(source, index: 1)
            var axis = pass == 0 ? scratch.axis : 1 - scratch.axis
            var halfOutput: Float = destination.pixelFormat == .rgba16Float ? 1 : 0
            var finalPass: UInt32 = pass == 1 ? 1 : 0
            encoder.setBytes(&axis, length: 4, index: 0)
            encoder.setBytes(&halfOutput, length: 4, index: 1)
            encoder.setBytes(&finalPass, length: 4, index: 2)
            let width = min(16, pipeline.threadExecutionWidth), height = max(1, min(16, pipeline.maxTotalThreadsPerThreadgroup / width))
            encoder.dispatchThreads(MTLSize(width: destination.width, height: destination.height, depth: 1), threadsPerThreadgroup: MTLSize(width: width, height: height, depth: 1))
            encoder.endEncoding()
        }
        return output
    }

    static func encodeRegion(filter: ImageRegionTransform, commandBuffer: MTLCommandBuffer,
                             textures: [MTLTexture], descriptor: KernelDescriptor) throws -> MTLTexture? {
        let matrix = filter.inverse
        let identity = descriptor.functionIdentity
        guard filter.interpolation == .lanczos, textures.count == 2,
              identity.functionConstants.isEmpty,
              identity.librarySource == .harbethFramework || (identity.librarySource == .automatic
                && BuiltinKernelAdmission.isUnmodified(["ImageRegionLanczosTransform"])),
              matrix[0].y == 0, matrix[0].z == 0, matrix[1].x == 0, matrix[1].z == 0,
              matrix[2].z.isFinite, abs(matrix[2].z) > 1e-8 else { return nil }
        let input = textures[1], output = textures[0]
        let footprint = SIMD2(abs(matrix[0].x / matrix[2].z) * Float(filter.outputRegion.width) / Float(output.width),
                              abs(matrix[1].y / matrix[2].z) * Float(filter.outputRegion.height) / Float(output.height))
        let scratchBytes = output.width * input.height * 16
        guard max(footprint.x, footprint.y) > 10, max(footprint.x, footprint.y) <= 2048,
              matrix[2].x.isFinite, matrix[2].y.isFinite,
              abs(matrix[2].x / matrix[2].z) < 1e7, abs(matrix[2].y / matrix[2].z) < 1e7,
              scratchBytes <= byteLimit else { return nil }
        guard let pipeline = try? HarbethContext.shared.makeComputePipelineState(identity: .init(
            kind: .compute, primaryName: "ImageRegionLanczosAxis", librarySource: .harbethFramework)),
              let lease = try? TextureLoader.makeTextureLease(width: output.width, height: input.height, options: [
            .texturePixelFormat: MTLPixelFormat.rgba32Float, .textureStorageMode: MTLStorageMode.private,
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])
              ], identifier: "ImageRegionLanczosAxis") else { return nil }
        commandBuffer.addCompletedHandler { _ in lease.release() }
        for axis: UInt32 in 0..<2 {
            let destination = axis == 0 ? lease.texture : output
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { throw HarbethError.makeComputeCommandEncoder }
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(destination, index: 0)
            encoder.setTexture(axis == 0 ? input : lease.texture, index: 1)
            do { try KernelBindingEncoder.encode(descriptor.parameterBindings, stage: .compute, on: encoder) }
            catch { encoder.endEncoding(); throw error }
            var pass = axis
            var size = SIMD2(Float(output.width), Float(output.height))
            encoder.setBytes(&pass, length: MemoryLayout<UInt32>.size, index: 6)
            encoder.setBytes(&size, length: MemoryLayout<SIMD2<Float>>.size, index: 7)
            let width = min(16, pipeline.threadExecutionWidth)
            let height = max(1, min(16, pipeline.maxTotalThreadsPerThreadgroup / width))
            encoder.dispatchThreads(MTLSize(width: destination.width, height: destination.height, depth: 1),
                threadsPerThreadgroup: MTLSize(width: width, height: height, depth: 1))
            encoder.endEncoding()
        }
        return output
    }
}

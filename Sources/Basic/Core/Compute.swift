//
//  Compute.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

/// 文档
/// https://colin19941.gitbooks.io/metal-programming-guide-zh/content/Data-Parallel_Compute_Processing_Compute_Command_Encoder.html

import Foundation
import MetalKit

struct Compute {
    /// Create a parallel computation pipeline.
    /// Performance intensive operations should not be invoked frequently
    /// - parameter kernel: Specifies the name of the data parallel computing coloring function
    /// - Returns: MTLComputePipelineState
    @inlinable static func makeComputePipelineState(with kernel: String) throws -> MTLComputePipelineState {
        /// 先读取缓存管线
        if let pipelineState = Shared.shared.device?.pipelineState(for: kernel) {
            return pipelineState
        }
        /// 同步阻塞编译计算程序来创建管道状态
        let function = try Device.readMTLFunction(kernel)
        guard let pipeline = try? Device.device().makeComputePipelineState(function: function) else {
            throw HarbethError.computePipelineState(kernel)
        }
        Shared.shared.device?.setPipelineState(pipeline, for: kernel)
        return pipeline
    }
    
    @inlinable static func makeComputePipelineState(with kernel: String, complete: @escaping (Result<MTLComputePipelineState, HarbethError>) -> Void) {
        /// 先读取缓存管线
        if let pipelineState = Shared.shared.device?.pipelineState(for: kernel) {
            complete(.success(pipelineState))
            return
        }
        guard let function = try? Device.readMTLFunction(kernel) else {
            complete(.failure(HarbethError.readFunction(kernel)))
            return
        }
        /// 异步创建管道状态
        Device.device().makeComputePipelineState(function: function) { pipelineState, error in
            guard let pipeline = pipelineState else {
                complete(.failure(HarbethError.computePipelineState(kernel)))
                return
            }
            complete(.success(pipeline))
            Shared.shared.device?.setPipelineState(pipeline, for: kernel)
        }
    }
    
    static func drawing(with kernel: String, commandBuffer: MTLCommandBuffer, textures: [MTLTexture], filter: C7FilterProtocol) throws -> MTLTexture {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }
        let pipelineState = try makeComputePipelineState(with: kernel)
        
        return encoding(computeEncoder: computeEncoder, pipelineState: pipelineState, textures: textures, filter: filter)
    }
    
    static func drawing(with kernel: String, commandBuffer: MTLCommandBuffer, textures: [MTLTexture], filter: C7FilterProtocol, complete: @escaping (Result<MTLTexture, HarbethError>) -> Void) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            complete(.failure(HarbethError.makeComputeCommandEncoder))
            return
        }
        makeComputePipelineState(with: kernel) { res in
            switch res {
            case .success(let pipelineState):
                let destTexture = encoding(computeEncoder: computeEncoder, pipelineState: pipelineState, textures: textures, filter: filter)
                complete(.success(destTexture))
            case .failure(let error):
                complete(.failure(error))
            }
        }
    }
    
    private static func encoding(computeEncoder: MTLComputeCommandEncoder, pipelineState: MTLComputePipelineState, textures: [MTLTexture], filter: C7FilterProtocol) -> MTLTexture {
        if case .compute(let kernel) = filter.modifier {
            computeEncoder.label = kernel + " encoder"
        }
        computeEncoder.setComputePipelineState(pipelineState)
        let destTexture = textures[0]
        for (index, texture) in textures.enumerated() {
            computeEncoder.setTexture(texture, index: index)
        }
        
        let size = MemoryLayout<Float>.size
        for i in 0..<filter.factors.count {
            var factor = filter.factors[i]
            computeEncoder.setBytes(&factor, length: size, index: i)
        }
        /// 配置像素总数参数
        var index: Int = filter.factors.count
        if filter.hasCount {
            var count = destTexture.width * destTexture.height
            computeEncoder.setBytes(&count, length: size, index: index)
            index += 1
        }
        /// 配置特殊参数非`Float`类型，例如4x4矩阵
        filter.setupSpecialFactors(for: computeEncoder, index: index)
        
        // Too large some Gpus are not supported. Too small gpus have low efficiency
        // 2D texture, depth set to 1
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        // -1 pixel to solve the problem that the edges of images are not drawn.
        // Minimum 1 pixel, solve the problem of zero without drawing.
        let width  = max(Int((destTexture.width + threadgroupSize.width - 1) / threadgroupSize.width), 1)
        let height = max(Int((destTexture.height + threadgroupSize.height - 1) / threadgroupSize.height), 1)
        //let threadGroups = MTLSizeMake(width, height, destTexture.arrayLength)
        let threadgroupCount = MTLSize(width: width, height: height, depth: 1)
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        #if targetEnvironment(macCatalyst)
        let blitEncoder = computeEncoder.commandBuffer?.makeBlitCommandEncoder()
        blitEncoder?.synchronize(resource: destTexture)
        blitEncoder?.endEncoding()
        #endif
        
        return destTexture
    }
}

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
import Metal

internal struct Compute {
    /// Create a parallel computation pipeline.
    /// Performance intensive operations should not be invoked frequently
    /// - parameter kernel: Specifies the name of the data parallel computing coloring function
    /// - Returns: MTLComputePipelineState
    @inlinable static func makeComputePipelineState(with kernel: String) throws -> MTLComputePipelineState {
        /// 先读取缓存管线
        if let pipelineState = Shared.shared.device?.pipelines[kernel] {
            return pipelineState
        }
        /// 同步阻塞编译计算程序来创建管道状态
        let function = try Device.readMTLFunction(kernel)
        guard let pipeline = try? Device.device().makeComputePipelineState(function: function) else {
            throw HarbethError.computePipelineState(kernel)
        }
        Shared.shared.device?.pipelines[kernel] = pipeline
        return pipeline
    }
    
    @inlinable static func makeComputePipelineState(with kernel: String, complete: @escaping (Result<MTLComputePipelineState, HarbethError>) -> Void) {
        /// 先读取缓存管线
        if let pipelineState = Shared.shared.device?.pipelines[kernel] {
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
            Shared.shared.device?.pipelines[kernel] = pipeline
        }
    }
}

extension C7FilterProtocol {
    
    func drawing(with kernel: String, commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HarbethError.makeComputeCommandEncoder
        }
        let pipelineState = try Compute.makeComputePipelineState(with: kernel)
        
        return encoding(computeEncoder: computeEncoder, pipelineState: pipelineState, textures: textures)
    }
    
    func drawing(with kernel: String, commandBuffer: MTLCommandBuffer, textures: [MTLTexture], complete: @escaping (Result<MTLTexture, HarbethError>) -> Void) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            complete(.failure(HarbethError.makeComputeCommandEncoder))
            return
        }
        Compute.makeComputePipelineState(with: kernel) { res in
            switch res {
            case .success(let pipelineState):
                let destTexture = encoding(computeEncoder: computeEncoder, pipelineState: pipelineState, textures: textures)
                complete(.success(destTexture))
            case .failure(let error):
                complete(.failure(error))
            }
        }
    }
    
    private func encoding(computeEncoder: MTLComputeCommandEncoder, pipelineState: MTLComputePipelineState, textures: [MTLTexture]) -> MTLTexture {
        computeEncoder.setComputePipelineState(pipelineState)
        
        let destTexture = textures[0]
        for (index, texture) in textures.enumerated() {
            computeEncoder.setTexture(texture, index: index)
        }
        
        let size = MemoryLayout<Float>.size
        for i in 0..<self.factors.count {
            var factor = self.factors[i]
            computeEncoder.setBytes(&factor, length: size, index: i)
        }
        /// 配置特殊参数非`Float`类型，例如4x4矩阵
        self.setupSpecialFactors(for: computeEncoder, index: self.factors.count - 1)
        
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
        
        return destTexture
    }
}

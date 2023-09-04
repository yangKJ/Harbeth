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
        Shared.shared.lock.lock()
        defer { Shared.shared.lock.unlock() }
        /// 先读取缓存管线
        if let pipelineState = Shared.shared.device?.pipelines[kernel] {
            return pipelineState
        }
        /// 同步阻塞编译计算程序来创建管道状态
        let function = try Device.readMTLFunction(kernel)
        guard let pipeline = try? Device.device().makeComputePipelineState(function: function) else {
            throw CustomError.computePipelineState(kernel)
        }
        Shared.shared.device?.pipelines[kernel] = pipeline
        return pipeline
    }
    
    @inlinable static func makeComputePipelineState(with kernel: String, complete: @escaping (Result<MTLComputePipelineState, CustomError>) -> Void) {
        Shared.shared.lock.lock()
        defer { Shared.shared.lock.unlock() }
        /// 先读取缓存管线
        if let pipelineState = Shared.shared.device?.pipelines[kernel] {
            complete(.success(pipelineState))
            return
        }
        guard let function = try? Device.readMTLFunction(kernel) else {
            complete(.failure(CustomError.readFunction(kernel)))
            return
        }
        /// 异步创建管道状态
        Device.device().makeComputePipelineState(function: function) { pipelineState, error in
            guard let pipeline = pipelineState else {
                complete(.failure(CustomError.computePipelineState(kernel)))
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
            throw CustomError.makeComputeCommandEncoder
        }
        let pipelineState = try Compute.makeComputePipelineState(with: kernel)
        
        return encoding(computeEncoder: computeEncoder, pipelineState: pipelineState, textures: textures)
    }
    
    func drawing(with kernel: String, commandBuffer: MTLCommandBuffer, textures: [MTLTexture], complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            complete(.failure(CustomError.makeComputeCommandEncoder))
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
        
        for (i, texture) in textures.enumerated() {
            computeEncoder.setTexture(texture, index: i)
        }
        
        let size = MemoryLayout<Float>.size
        let count = self.factors.count
        for i in 0..<count {
            var factor = self.factors[i]
            computeEncoder.setBytes(&factor, length: size, index: i)
        }
        
        if let filter = self as? ComputeProtocol {
            /// 配置特殊参数非`Float`类型，例如4x4矩阵
            filter.setupSpecialFactors(for: computeEncoder, index: count - 1)
        }
        
        // Too large some Gpus are not supported. Too small gpus have low efficiency
        // 2D texture, depth set to 1
        let threadGroupCount = MTLSize(width: 16, height: 16, depth: 1)
        let destTexture = textures[0]
        // +1 Objective To solve the problem that the edges of images are not drawn
        let w = max(Int((destTexture.width + threadGroupCount.width - 1) / threadGroupCount.width), 1)
        let h = max(Int((destTexture.height + threadGroupCount.height - 1) / threadGroupCount.height), 1)
        let threadGroups = MTLSizeMake(w, h, destTexture.arrayLength)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        computeEncoder.endEncoding()
        
        return destTexture
    }
}

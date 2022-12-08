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

internal struct Compute {
    /// Create a parallel computation pipeline.
    /// Performance intensive operations should not be invoked frequently
    ///
    /// - parameter kernel: Specifies the name of the data parallel computing coloring function
    /// - Returns: MTLComputePipelineState
    @inlinable static func makeComputePipelineState(with kernel: String) -> MTLComputePipelineState? {
        /// 先读取缓存管线
        if let pipelineState = Shared.shared.device?.pipelines[kernel] {
            return pipelineState
        }
        /// 同步阻塞编译计算程序来创建管道状态
        if let function = try? Device.readMTLFunction(kernel),
           let pipeline = try? Device.device().makeComputePipelineState(function: function) {
            Shared.shared.device?.pipelines[kernel] = pipeline
            return pipeline
        }
        return nil
    }
    
    @inlinable static func drawingProcess(_ pipelineState: MTLComputePipelineState,
                                          commandBuffer: MTLCommandBuffer,
                                          textures: [MTLTexture],
                                          filter: C7FilterProtocol) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        computeEncoder.setComputePipelineState(pipelineState)
        
        for (i, texture) in textures.enumerated() {
            computeEncoder.setTexture(texture, index: i)
        }
        
        let size = MemoryLayout<Float>.size
        let count = filter.factors.count
        for i in 0..<count {
            var factor = filter.factors[i]
            computeEncoder.setBytes(&factor, length: size, index: i)
        }
        
        if let filter = filter as? ComputeFiltering {
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
    }
}

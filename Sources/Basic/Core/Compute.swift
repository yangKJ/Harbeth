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
    static func makeComputePipelineState(with kernel: String) -> MTLComputePipelineState? {
        guard let function = try? Device.readMTLFunction(kernel) else { return nil }
        return try? Shared.shared.device!.device.makeComputePipelineState(function: function)
    }
    
    static func drawingProcess<T>(pipelineState: MTLComputePipelineState,
                                  commandBuffer: MTLCommandBuffer,
                                  textures: [MTLTexture],
                                  factors: [T]) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        computeEncoder.setComputePipelineState(pipelineState)
        
        for (index, texture) in textures.enumerated() {
            computeEncoder.setTexture(texture, index: index)
        }
        
        let device = Shared.shared.device!.device
        let size = MemoryLayout<T>.size
        for i in 0..<factors.count {
            var factor = factors[i]
            let buffer = device.makeBuffer(bytes: &factor, length: size, options: MTLResourceOptions.storageModeShared)
            computeEncoder.setBuffer(buffer, offset: 0, index: i)
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

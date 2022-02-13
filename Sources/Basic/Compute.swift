//
//  Compute.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

struct Compute {
    /// Create a parallel computation pipeline.
    /// https://colin19941.gitbooks.io/metal-programming-guide-zh
    ///
    /// - parameter kernel: Specifies the name of the data parallel computing coloring function
    /// - Returns: MTLComputePipelineState
    static func makeComputePipelineState(with kernel: String) -> MTLComputePipelineState {
        let function = Device.readMTLFunction(kernel)
        do {
            let pipelineState = try Device.shared.device.makeComputePipelineState(function: function)
            return pipelineState
        } catch {
            fatalError("Unable to setup Metal")
        }
    }
    
    static func process<T>(pipelineState: MTLComputePipelineState,
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
        
        let device = Device.shared.device
        let size = max(MemoryLayout<T>.size, 16)
        let buffer = device.makeBuffer(bytes: factors, length: size, options: MTLResourceOptions.storageModeShared)
        for i in 0..<factors.count {
            computeEncoder.setBuffer(buffer, offset: 0, index: i)
        }
        
        let threadGroupCount = MTLSize(width: 16, height: 16, depth: 1)
        let dstTexture = textures[0]
        // +1 目的解决得到的图片出现边缘未绘制问题
        let w = max(Int((dstTexture.width + threadGroupCount.width - 1) / threadGroupCount.width), 1)
        let h = max(Int((dstTexture.height + threadGroupCount.height - 1) / threadGroupCount.height), 1)
        let threadGroups = MTLSizeMake(w, h, dstTexture.arrayLength)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        
        computeEncoder.endEncoding()
    }
}

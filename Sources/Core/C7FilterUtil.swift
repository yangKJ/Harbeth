//
//  C7FilterUtil.swift
//  MetalQueenDemo
//
//  Created by Condy on 2022/2/11.
//

import Foundation
import MetalKit

public let kOneInputVertex: String = "oneInputVertex"
public let kTwoInputVertex: String = "twoInputVertex"

public struct C7FilterUtil {
    
    struct Compute { }
    struct Render { }
    
    /// 根据纹理参数，创建纹理用于后面存储
    /// - Parameters:
    ///   - pixelFormat: 像素格式
    ///   - width: 宽度
    ///   - height: 高度
    ///   - mipmapped: 是否需要映射
    /// - Returns: 新的纹理
    static func dstTexture(pixelFormat: MTLPixelFormat = MTLPixelFormat.rgba8Unorm,
                           width: Int, height: Int,
                           mipmapped: Bool = false) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: mipmapped)
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        guard let newTexture = RenderingDevice.shared.device.makeTexture(descriptor: descriptor) else {
            fatalError("Could not create texture of size: (\(width), \(height))")
        }
        return newTexture
    }
    
    /// 创建命令缓冲区
    static func makeCommandBuffer() -> MTLCommandBuffer? {
        let commandBuffer = RenderingDevice.shared.commandQueue.makeCommandBuffer()
        commandBuffer?.label = "QueenCommand"
        return commandBuffer
    }
}

extension C7FilterUtil.Compute {
    
    /// 创建一个并行计算管线
    /// https://colin19941.gitbooks.io/metal-programming-guide-zh
    /// - Parameter kernel: 数据并行计算着色函数名称
    /// - Returns: MTLComputePipelineState
    static func makeComputePipelineState(with kernel: String) -> MTLComputePipelineState {
        let function = RenderingDevice.shared.defaultLibrary.makeFunction(name: kernel)!
        do {
            let pipelineState = try RenderingDevice.shared.device.makeComputePipelineState(function: function)
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
        
        let device = RenderingDevice.shared.device
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

extension C7FilterUtil.Render {
    
    static func makeRenderPipelineState(with vertex: String, fragment: String) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        descriptor.rasterSampleCount = 1
        descriptor.vertexFunction = RenderingDevice.shared.defaultLibrary.makeFunction(name: vertex)
        descriptor.fragmentFunction = RenderingDevice.shared.defaultLibrary.makeFunction(name: fragment)
        do {
            let pipelineState = try RenderingDevice.shared.device.makeRenderPipelineState(descriptor: descriptor)
            return pipelineState
        } catch {
            fatalError("Could not create render pipeline state for vertex:\(vertex), fragment:\(fragment)")
        }
    }
    
    static func process<T>(pipelineState: MTLRenderPipelineState,
                           commandBuffer: MTLCommandBuffer,
                           inputTextures: [MTLTexture],
                           outputTexture: MTLTexture,
                           factors: [T]) {
        /// 渲染过程描述
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = outputTexture
        renderPass.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPass.colorAttachments[0].storeAction = MTLStoreAction.store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.65, 0.8, 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
        let device = RenderingDevice.shared.device
        let size = MemoryLayout<T>.size
        let vertexBuffer = device.makeBuffer(bytes: factors, length: factors.count * size, options: [])!
        
        renderEncoder.setFrontFacing(MTLWinding.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        /// 纹理坐标，左下角为坐标原点
        let standard: [Float] = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]
        let textureBuffer = device.makeBuffer(bytes: standard, length: standard.count * size, options: [])!
        for (index, texture) in inputTextures.enumerated() {
            renderEncoder.setVertexBuffer(textureBuffer, offset: 0, index: 1 + index)
            renderEncoder.setFragmentTexture(texture, index: index)
        }
        
        let uniformBuffer = device.makeBuffer(bytes: factors, length: factors.count * size, options: [])!
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}

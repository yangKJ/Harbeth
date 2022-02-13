//
//  Rendering.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

public let kOneInputVertex: String = "oneInputVertex"
public let kTwoInputVertex: String = "twoInputVertex"

struct Rendering {
    static func makeRenderPipelineState(with vertex: String, fragment: String) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        descriptor.rasterSampleCount = 1
        descriptor.vertexFunction = RenderingDevice.readMTLFunction(vertex)
        descriptor.fragmentFunction = RenderingDevice.readMTLFunction(fragment)
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

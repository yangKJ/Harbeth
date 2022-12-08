//
//  Rendering.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

internal struct Rendering {
    public static let kOneInputVertex: String = "oneInputVertex"
    public static let kTwoInputVertex: String = "twoInputVertex"
    
    static func makeRenderPipelineState(with vertex: String, fragment: String) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        descriptor.rasterSampleCount = 1
        descriptor.vertexFunction = try? Device.readMTLFunction(vertex)
        descriptor.fragmentFunction = try? Device.readMTLFunction(fragment)
        return try? Device.device().makeRenderPipelineState(descriptor: descriptor)
    }
    
    static func drawingProcess(_ pipelineState: MTLRenderPipelineState,
                               commandBuffer: MTLCommandBuffer,
                               texture: MTLTexture,
                               filter: C7FilterProtocol) {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = texture
        renderPass.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPass.colorAttachments[0].storeAction = MTLStoreAction.store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.65, 0.8, 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            C7FailedErrorInDebug("Could not create render encoder")
            return
        }
        let device = Device.device()
        let size = MemoryLayout<Float>.size
        
        renderEncoder.setFrontFacing(MTLWinding.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        /// 纹理坐标，左下角为坐标原点
        let standard: [Float] = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]
        let textureBuffer = device.makeBuffer(bytes: standard, length: standard.count * size, options: [])!
        renderEncoder.setVertexBuffer(textureBuffer, offset: 0, index: 0)
        //renderEncoder.setFragmentTexture(texture, index: 0)
        
        var vertexCount: Int = 1
        if let filter = filter as? RenderFiltering, let buffer = filter.setupVertexUniformBuffer(for: device) {
            renderEncoder.setVertexBuffer(buffer, offset: 0, index: vertexCount)
            vertexCount += 1
        }
        
        if filter.factors.isEmpty == false,
           let uniformBuffer = device.makeBuffer(bytes: filter.factors, length: filter.factors.count * size, options: []) {
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: vertexCount)
            vertexCount += 1
        }
        
//        var inTextures = textures; inTextures.removeFirst()
//        for (i, texture) in inTextures.enumerated() {
//            renderEncoder.setVertexBuffer(textureBuffer, offset: 0, index: i + 1)
//            renderEncoder.setFragmentTexture(texture, index: i)
//        }
//
//        let uniformBuffer = device.makeBuffer(bytes: factors, length: factors.count * size, options: [])!
//        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount, instanceCount: 1)
        renderEncoder.endEncoding()
    }
}

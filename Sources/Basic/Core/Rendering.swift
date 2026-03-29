//
//  Rendering.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

struct Rendering {
    
    static func makeRenderPipelineState(with vertex: String, fragment: String) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        descriptor.rasterSampleCount = 1
        descriptor.vertexFunction = try Device.readMTLFunction(vertex)
        descriptor.fragmentFunction = try Device.readMTLFunction(fragment)
        guard let pipelineState = try? Device.device().makeRenderPipelineState(descriptor: descriptor) else {
            throw HarbethError.renderPipelineState(vertex, fragment)
        }
        return pipelineState
    }
    
    static func drawing(_ pipelineState: MTLRenderPipelineState, commandBuffer: MTLCommandBuffer, texture: MTLTexture, destTexture: MTLTexture, filter: C7FilterProtocol) {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = destTexture
        renderPass.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPass.colorAttachments[0].storeAction = MTLStoreAction.store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            HarbethError.failed("Could not create render encoder")
            return
        }
        let device = Device.device()
        let size = MemoryLayout<Float>.size
        
        renderEncoder.setFrontFacing(MTLWinding.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        /// The origin of Metal texture coordinates is in the upper left corner, so the y-axis needs to be flipped.
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,
             1.0, -1.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 0.0,
             1.0,  1.0, 1.0, 0.0,
        ]
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * size, options: [])!
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        /// Set the input texture
        renderEncoder.setFragmentTexture(texture, index: 0)
        
        /// Handle other input textures
        for (i, inputTexture) in filter.otherInputTextures.enumerated() {
            renderEncoder.setFragmentTexture(inputTexture, index: i + 1)
        }
        
        var bufferIndex: Int = 1
        if let buffer = (filter as? RenderProtocol)?.setupVertexUniformBuffer(for: device) {
            renderEncoder.setVertexBuffer(buffer, offset: 0, index: bufferIndex)
            bufferIndex += 1
        }
        
        let length = filter.factors.count * size
        if !filter.factors.isEmpty, let uniformBuffer = device.makeBuffer(bytes: filter.factors, length: length, options: []) {
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        }
        
        /// Draw a quadrilateral (two triangles)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        renderEncoder.endEncoding()
    }
}

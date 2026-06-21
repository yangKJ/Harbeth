//
//  Rendering.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

struct Rendering {
    
    static func makeRenderPipelineState(with vertex: String,
                                        fragment: String,
                                        pixelFormat: MTLPixelFormat,
                                        sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        try Shared.shared.defaultContext.makeRenderPipelineState(
            vertex: vertex,
            fragment: fragment,
            pixelFormat: pixelFormat,
            sampleCount: sampleCount
        )
    }

    static func makeRenderPipelineState(vertexIdentity: HarbethKernelFunctionIdentity,
                                        fragmentIdentity: HarbethKernelFunctionIdentity,
                                        pixelFormat: MTLPixelFormat,
                                        sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        try Shared.shared.defaultContext.makeRenderPipelineState(
            vertexIdentity: vertexIdentity,
            fragmentIdentity: fragmentIdentity,
            pixelFormat: pixelFormat,
            sampleCount: sampleCount
        )
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
        let device = Shared.shared.metalDevice
        let size = MemoryLayout<Float>.size
        
        renderEncoder.setFrontFacing(MTLWinding.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        /// The origin of Metal texture coordinates is in the upper left corner, so the y-axis needs to be flipped.
        let defaultVertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,
             1.0, -1.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 0.0,
             1.0,  1.0, 1.0, 0.0,
        ]
        let inputSize = C7Size(width: texture.width, height: texture.height)
        let customVertices = (filter as? RenderProtocol)?.setupVertices(inputSize: inputSize)
        let vertexStride = (filter as? RenderProtocol)?.renderVertexStride ?? 4
        let vertices = customVertices ?? defaultVertices
        let vertexCount = max(vertices.count / vertexStride, 0)
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * size, options: [])!
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        /// Set the input texture
        renderEncoder.setFragmentTexture(texture, index: 0)
        
        /// Handle other input textures
        for (i, inputTexture) in filter.otherInputTextures.enumerated() {
            renderEncoder.setFragmentTexture(inputTexture, index: i + 1)
        }
        
        var bufferIndex: Int = 1
        let renderFilter = filter as? RenderProtocol
        if let buffer = renderFilter?.setupVertexUniformBuffer(for: device) {
            renderEncoder.setVertexBuffer(buffer, offset: 0, index: bufferIndex)
            bufferIndex += 1
        }

        var fragmentBufferIndex = 0
        if let buffer = renderFilter?.setupFragmentUniformBuffer(for: device, inputSize: inputSize) {
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: fragmentBufferIndex)
            fragmentBufferIndex += 1
        }

        let length = filter.factors.count * size
        if !filter.factors.isEmpty, let uniformBuffer = device.makeBuffer(bytes: filter.factors, length: length, options: []) {
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: fragmentBufferIndex)
        }
        
        /// Draw a quadrilateral (two triangles)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexCount, instanceCount: 1)
        renderEncoder.endEncoding()
    }
}

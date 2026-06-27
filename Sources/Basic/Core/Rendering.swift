//
//  Rendering.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

struct Rendering {

    static let defaultVertices: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
         1.0, -1.0, 1.0, 1.0,
        -1.0,  1.0, 0.0, 0.0,
         1.0,  1.0, 1.0, 0.0,
    ]
    
    static func makeRenderPipelineState(with vertex: String, fragment: String, pixelFormat: MTLPixelFormat, sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        try Shared.shared.defaultContext.makeRenderPipelineState(
            vertex: vertex,
            fragment: fragment,
            pixelFormat: pixelFormat,
            sampleCount: sampleCount
        )
    }

    static func makeRenderPipelineState(vertexIdentity: KernelFunctionIdentity,
                                        fragmentIdentity: KernelFunctionIdentity,
                                        pixelFormat: MTLPixelFormat,
                                        sampleCount: Int = 1) throws -> MTLRenderPipelineState {
        try Shared.shared.defaultContext.makeRenderPipelineState(
            vertexIdentity: vertexIdentity,
            fragmentIdentity: fragmentIdentity,
            pixelFormat: pixelFormat,
            sampleCount: sampleCount
        )
    }

    static func makeRenderPipelineState(vertexIdentity: KernelFunctionIdentity,
                                        fragmentIdentity: KernelFunctionIdentity,
                                        renderPass: RenderPassContract) throws -> MTLRenderPipelineState {
        try Shared.shared.defaultContext.makeRenderPipelineState(
            vertexIdentity: vertexIdentity,
            fragmentIdentity: fragmentIdentity,
            renderPass: renderPass
        )
    }
    
    static func drawing(_ pipelineState: MTLRenderPipelineState, commandBuffer: MTLCommandBuffer, texture: MTLTexture, destTexture: MTLTexture, filter: C7FilterProtocol) {
        guard let renderFilter = filter as? RenderProtocol else {
            assertionFailure("Render command requires RenderProtocol.")
            return
        }
        let inputSize = C7Size(width: texture.width, height: texture.height)
        let usesCustomVertexLayout = renderFilter.renderVertexStride != 4
            || renderFilter.setupVertices(inputSize: inputSize) != nil
        let renderPass = resolveRenderPass(
            filter: renderFilter,
            inputSize: inputSize,
            destTexture: destTexture,
            usesCustomVertexLayout: usesCustomVertexLayout
        )
        let command = RenderCommand(
            filter: renderFilter,
            sourceTexture: texture,
            renderPass: renderPass
        )
        guard let batch = try? RenderCommandBatch(
            renderPass: renderPass,
            destinationTexturesByAttachmentIndex: [0: destTexture],
            commands: [command]
        ) else {
            assertionFailure("Could not create render command batch.")
            return
        }
        try? encode(batch: batch, with: pipelineState, commandBuffer: commandBuffer)
    }

    static func encode(batch: RenderCommandBatch, commandBuffer: MTLCommandBuffer) throws {
        let renderPass = try batch.renderPass.makeDescriptor(
            destinationTexturesByAttachmentIndex: batch.destinationTexturesByAttachmentIndex
        )
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            throw HarbethError.commandBuffer
        }
        renderEncoder.setFrontFacing(MTLWinding.counterClockwise)
        for command in batch.commands {
            let pipelineState = try makeRenderPipelineState(
                vertexIdentity: command.descriptor.vertexFunction,
                fragmentIdentity: command.descriptor.fragmentFunction,
                renderPass: batch.renderPass
            )
            encode(command: command, pipelineState: pipelineState, renderEncoder: renderEncoder)
        }
        renderEncoder.endEncoding()
    }

    static func encode(batch: RenderCommandBatch, with pipelineState: MTLRenderPipelineState, commandBuffer: MTLCommandBuffer) throws {
        let renderPass = try batch.renderPass.makeDescriptor(
            destinationTexturesByAttachmentIndex: batch.destinationTexturesByAttachmentIndex
        )
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            throw HarbethError.commandBuffer
        }
        renderEncoder.setFrontFacing(MTLWinding.counterClockwise)
        for command in batch.commands {
            encode(command: command, pipelineState: pipelineState, renderEncoder: renderEncoder)
        }
        renderEncoder.endEncoding()
    }

    private static func encode(command: RenderCommand, pipelineState: MTLRenderPipelineState, renderEncoder: MTLRenderCommandEncoder) {
        let texture = command.sourceTexture
        let filter = command.filter
        let device = Shared.shared.metalDevice
        let inputSize = C7Size(width: texture.width, height: texture.height)
        let size = MemoryLayout<Float>.size
        renderEncoder.setRenderPipelineState(pipelineState)

        let customVertices = filter.setupVertices(inputSize: inputSize)
        let vertexStride = filter.renderVertexStride
        let vertices = customVertices ?? defaultVertices
        let vertexCount = max(vertices.count / vertexStride, 0)
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * size, options: [])!
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        if let samplerState = Shared.shared.defaultContext.makeSamplerState(filter.renderSamplerDescriptor) {
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        }

        renderEncoder.setFragmentTexture(texture, index: 0)

        for (i, inputTexture) in filter.otherInputTextures.enumerated() {
            renderEncoder.setFragmentTexture(inputTexture, index: i + 1)
        }
        
        var bufferIndex: Int = 1
        if let buffer = filter.setupVertexUniformBuffer(for: device) {
            renderEncoder.setVertexBuffer(buffer, offset: 0, index: bufferIndex)
            bufferIndex += 1
        }

        var fragmentBufferIndex = 0
        if let buffer = filter.setupFragmentUniformBuffer(for: device, inputSize: inputSize) {
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: fragmentBufferIndex)
            fragmentBufferIndex += 1
        }

        let length = filter.factors.count * size
        if !filter.factors.isEmpty, let uniformBuffer = device.makeBuffer(bytes: filter.factors, length: length, options: []) {
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: fragmentBufferIndex)
        }

        KernelBindingEncoder.encode(command.descriptor.parameterBindings, stage: .renderVertex, on: renderEncoder)
        KernelBindingEncoder.encode(command.descriptor.parameterBindings, stage: .renderFragment, on: renderEncoder)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexCount, instanceCount: 1)
    }

    /// Resolves the `RenderPassContract` for a single-filter draw call.
    ///
    /// Conservative pass-through:
    /// - Default path: `RenderPassContract.singleColor(...)` to preserve the
    ///   existing visual output shape (single color attachment, MRT off).
    /// - If `filter.kernelDescriptor(inputSize:).passes.first?.renderPass`
    ///   declares a `sampleCount` that matches `destTexture.sampleCount`,
    ///   that contract's sampleCount is adopted so multisample targets get
    ///   negotiated correctly.
    /// - MRT / additional attachments are NOT yet adopted — shaders don't
    ///   universally declare MRT output, so widening the contract would
    ///   risk silent visual regressions. Kept as a future toggle.
    static func resolveRenderPass(filter: RenderProtocol,
                                  inputSize: C7Size,
                                  destTexture: MTLTexture,
                                  usesCustomVertexLayout: Bool) -> RenderPassContract {
        let fallback = RenderPassContract.singleColor(
            pixelFormat: destTexture.pixelFormat,
            sampleCount: max(destTexture.sampleCount, 1),
            usesCustomVertexLayout: usesCustomVertexLayout
        )
        let descriptor = filter.kernelDescriptor(inputSize: inputSize)
        guard let declared = descriptor.passes.first?.renderPass else {
            return fallback
        }
        // Only adopt declared sampleCount when it agrees with the destination
        // texture — otherwise the `RenderPassContract.validate(...)` check
        // inside `makeDescriptor` would throw at encode time.
        let declaredSampleCount = max(declared.sampleCount, 1)
        let destSampleCount = max(destTexture.sampleCount, 1)
        guard declaredSampleCount == destSampleCount else {
            return fallback
        }
        // Keep singleColor shape: do NOT adopt declared.colorAttachments when
        // the count diverges from 1, to avoid silent MRT regression on shaders
        // that don't declare additional outputs.
        guard declared.colorAttachments.count == 1 else {
            return fallback
        }
        return RenderPassContract.singleColor(
            pixelFormat: destTexture.pixelFormat,
            sampleCount: destSampleCount,
            usesCustomVertexLayout: declared.usesCustomVertexLayout || usesCustomVertexLayout
        )
    }
}

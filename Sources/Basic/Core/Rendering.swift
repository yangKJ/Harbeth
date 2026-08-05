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
        try HarbethContext.shared.makeRenderPipelineState(
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
        try HarbethContext.shared.makeRenderPipelineState(
            vertexIdentity: vertexIdentity,
            fragmentIdentity: fragmentIdentity,
            pixelFormat: pixelFormat,
            sampleCount: sampleCount
        )
    }

    static func makeRenderPipelineState(vertexIdentity: KernelFunctionIdentity, fragmentIdentity: KernelFunctionIdentity, renderPass: RenderPassContract) throws -> MTLRenderPipelineState {
        try HarbethContext.shared.makeRenderPipelineState(
            vertexIdentity: vertexIdentity,
            fragmentIdentity: fragmentIdentity,
            renderPass: renderPass
        )
    }
    
    static func drawing(_ pipelineState: MTLRenderPipelineState, commandBuffer: MTLCommandBuffer, texture: MTLTexture, destTexture: MTLTexture, filter: C7FilterProtocol) throws {
        guard let renderFilter = filter as? RenderProtocol else {
            throw HarbethError.filterProcessingFailed("Render command requires RenderProtocol.")
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
        let command = RenderCommand(filter: renderFilter, sourceTexture: texture, renderPass: renderPass)
        let batch = try RenderCommandBatch(
            renderPass: renderPass,
            destinationTexturesByAttachmentIndex: [0: destTexture],
            commands: [command]
        )
        try encode(batch: batch, with: pipelineState, commandBuffer: commandBuffer)
    }

    /// 使用滤镜声明的 topology、blend 与 sample count 编码单个 Render 原子。
    static func drawing(commandBuffer: MTLCommandBuffer,
                        texture: MTLTexture,
                        destTexture: MTLTexture,
                        filter: C7FilterProtocol) throws {
        guard let renderFilter = filter as? RenderProtocol else {
            throw HarbethError.filterProcessingFailed("Render command requires RenderProtocol.")
        }
        let requestedSampleCount = max(renderFilter.renderRasterSampleCount, 1)
        guard HarbethContext.shared.device.supportsTextureSampleCount(requestedSampleCount) else {
            throw HarbethError.configurationInvalid(
                "Render raster sample count \(requestedSampleCount) is unsupported by the active Metal device."
            )
        }
        guard requestedSampleCount == 1 || renderFilter.renderPreloadsSourceTexture == false else {
            throw HarbethError.configurationInvalid(
                "Multisample render filters cannot preload a single-sample source texture."
            )
        }

        let aliasesSource = sharesStorage(texture, destTexture)
        let singleSampleOutput: MTLTexture
        if aliasesSource {
            singleSampleOutput = try TextureLoader.makeTexture(
                width: destTexture.width,
                height: destTexture.height,
                options: [
                    .texturePixelFormat: destTexture.pixelFormat,
                    .textureUsage: MTLTextureUsage.shaderRead.union(.shaderWrite).union(.renderTarget)
                ],
                identifier: "Rendering.AliasStagingTarget"
            )
        } else {
            singleSampleOutput = destTexture
        }
        guard singleSampleOutput.usage.contains(.renderTarget) else {
            throw HarbethError.configurationInvalid(
                "Render output texture for \(renderFilter.identifier) must declare MTLTextureUsage.renderTarget; usage=\(singleSampleOutput.usage.rawValue)."
            )
        }

        if renderFilter.renderPreloadsSourceTexture {
            guard texture.width == singleSampleOutput.width,
                  texture.height == singleSampleOutput.height,
                  texture.pixelFormat == singleSampleOutput.pixelFormat else {
                throw HarbethError.configurationInvalid(
                    "Render source preload and output require matching size and pixel format."
                )
            }
            try copy(texture, to: singleSampleOutput, commandBuffer: commandBuffer)
        }

        let renderTarget: MTLTexture
        let resolveTargets: [Int: MTLTexture]
        if requestedSampleCount > 1 {
            renderTarget = try TextureLoader.makeTexture(
                width: singleSampleOutput.width,
                height: singleSampleOutput.height,
                options: [
                    .texturePixelFormat: singleSampleOutput.pixelFormat,
                    .textureUsage: MTLTextureUsage.renderTarget,
                    .textureSampleCount: requestedSampleCount
                ],
                identifier: "Rendering.MultisampleTarget"
            )
            resolveTargets = [0: singleSampleOutput]
        } else {
            renderTarget = singleSampleOutput
            resolveTargets = [:]
        }

        let inputSize = C7Size(texture: texture)
        let usesCustomVertexLayout = renderFilter.renderVertexStride != 4
            || renderFilter.setupVertices(inputSize: inputSize) != nil
        let renderPass = RenderPassContract.singleColor(
            pixelFormat: renderTarget.pixelFormat,
            sampleCount: requestedSampleCount,
            usesCustomVertexLayout: usesCustomVertexLayout,
            loadBehavior: renderFilter.renderPreloadsSourceTexture ? .load : .clear,
            storeBehavior: requestedSampleCount > 1 ? .multisampleResolve : .store,
            blendMode: renderFilter.renderBlendMode
        )
        let command = RenderCommand(filter: renderFilter, sourceTexture: texture, renderPass: renderPass)
        let batch = try RenderCommandBatch(
            renderPass: renderPass,
            destinationTexturesByAttachmentIndex: [0: renderTarget],
            resolveTexturesByAttachmentIndex: resolveTargets,
            commands: [command]
        )
        try encode(batch: batch, commandBuffer: commandBuffer)
        if aliasesSource {
            try copy(singleSampleOutput, to: destTexture, commandBuffer: commandBuffer)
        }

        var texturesToRecycle: [MTLTexture] = []
        if requestedSampleCount > 1 {
            texturesToRecycle.append(renderTarget)
        }
        if aliasesSource {
            texturesToRecycle.append(singleSampleOutput)
        }
        if texturesToRecycle.isEmpty == false {
            let transfer = HarbethUncheckedTransfer(value: texturesToRecycle)
            commandBuffer.addCompletedHandler { _ in
                HarbethContext.shared.texturePool.enqueueTexturesSync(transfer.value)
            }
        }
    }

    static func encode(batch: RenderCommandBatch, commandBuffer: MTLCommandBuffer) throws {
        let renderPass = try batch.renderPass.makeDescriptor(
            destinationTexturesByAttachmentIndex: batch.destinationTexturesByAttachmentIndex,
            resolveTexturesByAttachmentIndex: batch.resolveTexturesByAttachmentIndex
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
            destinationTexturesByAttachmentIndex: batch.destinationTexturesByAttachmentIndex,
            resolveTexturesByAttachmentIndex: batch.resolveTexturesByAttachmentIndex
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
        let device = HarbethContext.shared.device
        let inputSize = C7Size(width: texture.width, height: texture.height)
        let size = MemoryLayout<Float>.size
        renderEncoder.setRenderPipelineState(pipelineState)

        let customVertices = filter.setupVertices(inputSize: inputSize)
        let vertexStride = filter.renderVertexStride
        let vertices = customVertices ?? defaultVertices
        let vertexCount = max(vertices.count / vertexStride, 0)
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * size, options: [])!
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        if filter.renderSamplerConsumption == .runtimeBound,
           let samplerState = HarbethContext.shared.makeSamplerState(filter.renderSamplerDescriptor) {
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

        renderEncoder.drawPrimitives(
            type: filter.renderPrimitiveTopology.metalValue,
            vertexStart: 0,
            vertexCount: vertexCount,
            instanceCount: 1
        )
    }

    private static func copy(_ source: MTLTexture, to destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.makeBlitCommandEncoder
        }
        blitEncoder.copy(
            from: source,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: .init(x: 0, y: 0, z: 0),
            sourceSize: .init(width: source.width, height: source.height, depth: 1),
            to: destination,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: .init(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()
    }

    private static func sharesStorage(_ lhs: MTLTexture, _ rhs: MTLTexture) -> Bool {
        if lhs === rhs { return true }

        func rootTexture(_ texture: MTLTexture) -> MTLTexture {
            var root = texture
            while let parent = root.parent {
                root = parent
            }
            return root
        }

        if rootTexture(lhs) === rootTexture(rhs) { return true }
        if let lhsBuffer = lhs.buffer, let rhsBuffer = rhs.buffer, lhsBuffer === rhsBuffer {
            return true
        }
        return false
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
    static func resolveRenderPass(filter: RenderProtocol, inputSize: C7Size, destTexture: MTLTexture, usesCustomVertexLayout: Bool) -> RenderPassContract {
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

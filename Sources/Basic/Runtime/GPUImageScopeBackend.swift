//
//  GPUImageScopeBackend.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
import Metal

enum GPUImageScopeBackend {
    static func render(texture: MTLTexture, configuration: TextureImageScopeConfiguration) throws -> RenderedTextureImageScope {
        guard texture.device === HarbethContext.shared.device,
              let commandBuffer = HarbethContext.shared.makeCommandBuffer() else {
            throw HarbethError.configurationInvalid("Image scope requires the Harbeth context Metal device.")
        }
        let result = try encode(texture: texture, configuration: configuration, into: commandBuffer)
        do {
            try commandBuffer.commitAndWaitUntilCompleted(identifier: "GPUImageScope.\(configuration.kind.rawValue)")
            return result
        } catch {
            HarbethContext.shared.texturePool.enqueueTextureSync(result.texture)
            throw error
        }
    }

    static func encode(
        texture: MTLTexture,
        configuration: TextureImageScopeConfiguration,
        into commandBuffer: MTLCommandBuffer
    ) throws -> RenderedTextureImageScope {
        guard texture.device === HarbethContext.shared.device,
              commandBuffer.device === HarbethContext.shared.device else {
            throw HarbethError.configurationInvalid("Image scope requires source texture, output texture, command buffer, and Harbeth context to share one Metal device.")
        }
        guard commandBuffer.retainedReferences else {
            throw HarbethError.configurationInvalid("Image scope requires a command buffer that retains encoded resources.")
        }
        guard commandBuffer.status == .notEnqueued else {
            throw HarbethError.configurationInvalid("Image scope requires a command buffer that still accepts encoding.")
        }
        let outputPixelFormat = configuration.pixelFormat.metalPixelFormat ?? .rgba16Float
        let outputTexture = try TextureLoader.makeTexture(
            width: configuration.width,
            height: configuration.height,
            options: [
                .texturePixelFormat: outputPixelFormat,
                .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite])
            ],
            identifier: "GPUImageScope.\(configuration.kind.rawValue)"
        )
        do {
            let densityChannelCount = configuration.kind == .rgbWaveform ? 3 : 1
            let densityCount = configuration.width * configuration.height * densityChannelCount
            let densityLength = densityCount * MemoryLayout<UInt32>.stride
            guard let densityBuffer = texture.device.makeBuffer(length: densityLength, options: .storageModeShared),
                  let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw HarbethError.commandBuffer
            }
            memset(densityBuffer.contents(), 0, densityLength)

            let accumulationPipeline = try Compute.makeComputePipelineState(with: "imageScopeAccumulateKernel")
            let visualizationPipeline = try Compute.makeComputePipelineState(with: "imageScopeVisualizationKernel")
            var parameters = ImageScopeParameters(
                kind: configuration.kind.rawValueForShader,
                scopeWidth: UInt32(configuration.width),
                scopeHeight: UInt32(configuration.height),
                sourceWidth: UInt32(texture.width),
                sourceHeight: UInt32(texture.height),
                densityChannelCount: UInt32(densityChannelCount),
                intensity: configuration.intensity,
                densityScale: configuration.normalizesDensity
                    ? max(Float(texture.width * texture.height) / Float(1920 * 1080), 0.000001)
                    : 1,
                valueMinimum: configuration.valueRange.minimum,
                valueMaximum: configuration.valueRange.maximum
            )

            encoder.label = "Harbeth.GPUImageScope.\(configuration.kind.rawValue)"
            encoder.setComputePipelineState(accumulationPipeline)
            encoder.setTexture(texture, index: 0)
            encoder.setBuffer(densityBuffer, offset: 0, index: 0)
            encoder.setBytes(&parameters, length: MemoryLayout<ImageScopeParameters>.stride, index: 1)
            dispatch(encoder: encoder, pipeline: accumulationPipeline, width: texture.width, height: texture.height)
            encoder.memoryBarrier(resources: [densityBuffer])

            encoder.setComputePipelineState(visualizationPipeline)
            encoder.setBuffer(densityBuffer, offset: 0, index: 0)
            encoder.setBytes(&parameters, length: MemoryLayout<ImageScopeParameters>.stride, index: 1)
            encoder.setTexture(outputTexture, index: 0)
            dispatch(
                encoder: encoder,
                pipeline: visualizationPipeline,
                width: configuration.width,
                height: configuration.height
            )
            encoder.endEncoding()
        } catch {
            HarbethContext.shared.texturePool.enqueueTextureSync(outputTexture)
            throw error
        }

        let contract: RenderOutputAttachmentContract
        switch configuration.kind {
        case .luminanceWaveform, .rgbWaveform:
            contract = .waveform(index: 1, pixelFormat: configuration.pixelFormat)
        case .vectorscope:
            contract = .vectorscope(index: 1, pixelFormat: configuration.pixelFormat)
        }
        return RenderedTextureImageScope(
            configuration: configuration,
            attachment: RenderedAttachment(
                index: 1,
                semantic: contract.semantic,
                texture: outputTexture,
                debugPolicy: contract.debugPolicy
            )
        )
    }

    private static func dispatch(encoder: MTLComputeCommandEncoder, pipeline: MTLComputePipelineState, width: Int, height: Int) {
        let threadWidth = min(max(pipeline.threadExecutionWidth, 1), max(width, 1))
        let threadHeight = min(
            max(pipeline.maxTotalThreadsPerThreadgroup / threadWidth, 1),
            max(height, 1)
        )
        let threads = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        let groups = MTLSize(
            width: max((width + threadWidth - 1) / threadWidth, 1),
            height: max((height + threadHeight - 1) / threadHeight, 1),
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
    }
}

private struct ImageScopeParameters {
    let kind: UInt32
    let scopeWidth: UInt32
    let scopeHeight: UInt32
    let sourceWidth: UInt32
    let sourceHeight: UInt32
    let densityChannelCount: UInt32
    let intensity: Float
    let densityScale: Float
    let valueMinimum: Float
    let valueMaximum: Float
}

private extension TextureImageScopeKind {
    var rawValueForShader: UInt32 {
        switch self {
        case .luminanceWaveform: return 0
        case .rgbWaveform: return 1
        case .vectorscope: return 2
        }
    }
}

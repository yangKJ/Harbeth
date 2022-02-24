//
//  C7FilterOutput.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

public protocol C7FilterOutput {
    
    /// Filter processing
    /// - Parameters:
    ///   - filter: It must be an object implementing C7FilterProtocol
    /// - Returns: C7FilterSerializer
    mutating func make<T: C7FilterOutput>(filter: C7FilterProtocol) throws -> T
    
    /// Multiple filter combinations
    /// Please note that the order in which filters are added may affect the result of image generation.
    ///
    /// - Parameters:
    ///   - filters: Filter group, It must be an object implementing C7FilterProtocol
    /// - Returns: C7FilterOutput
    mutating func makeGroup<T: C7FilterOutput>(filters: [C7FilterProtocol]) throws -> T
}

extension C7FilterOutput {
    /// Create a new texture based on the filter content.
    /// This protocol method does not need to be overridden unless you need to change the internal logic.
    ///
    /// - Parameters:
    ///   - intexture: Input texture
    ///   - otherTextures: Other input textures
    ///   - filter: It must be an object implementing C7FilterProtocol
    /// - Returns: New texture after processing
    func generateOutTexture(inTexture: MTLTexture, filter: C7FilterProtocol) throws -> MTLTexture {
        guard let commandBuffer = makeCommandBuffer() else {
            throw C7CustomError.commandBuffer
        }
        let outputSize = filter.outputSize(input: (inTexture.width, inTexture.height))
        let outTexture = destTexture(width: outputSize.width, height: outputSize.height)
        if case .compute(let kernel) = filter.modifier {
            guard let pipelineState = Compute.makeComputePipelineState(with: kernel) else {
                throw C7CustomError.computePipelineState(kernel)
            }
            var textures = [outTexture, inTexture]
            textures += filter.otherInputTextures
            Compute.drawingProcess(pipelineState, commandBuffer: commandBuffer, textures: textures, filter: filter)
        } else if case .render(let vertex, let fragment) = filter.modifier {
            guard let pipelineState = Rendering.makeRenderPipelineState(with: vertex, fragment: fragment) else {
                return inTexture
            }
            var textures = [inTexture]
            textures += filter.otherInputTextures
            Rendering.drawingProcess(pipelineState: pipelineState,
                                     commandBuffer: commandBuffer,
                                     inputTextures: textures,
                                     outputTexture: outTexture,
                                     factors: filter.factors)
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outTexture
    }
}

extension C7FilterOutput {
    
    /// Create a texture for later storage according to the texture parameters.
    /// - Parameters:
    ///    - pixelformat: Indicates the pixelFormat, The format of the picture should be consistent with the data
    ///    - width: The texture width
    ///    - height: The texture height
    ///    - mipmAPPED: No mapping was required
    /// - Returns: New textures
    private func destTexture(pixelFormat: MTLPixelFormat = MTLPixelFormat.rgba8Unorm,
                             width: Int, height: Int,
                             mipmapped: Bool = false) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: mipmapped)
        descriptor.usage = [.shaderRead, .shaderWrite]
        return Device.device().makeTexture(descriptor: descriptor)!
    }
    
    /// Create command buffer.
    private func makeCommandBuffer() -> MTLCommandBuffer? {
        let commandBuffer = Shared.shared.device!.commandQueue.makeCommandBuffer()
        commandBuffer?.label = "QueenCommand"
        return commandBuffer
    }
}

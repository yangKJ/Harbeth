//
//  Processed.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit
import MetalPerformanceShaders

internal struct Processed {
    /// Create a new texture based on the filter content.
    /// This protocol method does not need to be overridden unless you need to change the internal logic.
    ///
    /// - Parameters:
    ///   - intexture: Input texture
    ///   - outTexture: Output texture
    ///   - filter: It must be an object implementing C7FilterProtocol
    /// - Returns: Output texture after processing
    @inlinable @discardableResult
    static func IO(inTexture: MTLTexture, outTexture: MTLTexture? = nil, filter: C7FilterProtocol) throws -> MTLTexture {
        if case .coreimage(let name) = filter.modifier {
            return COImage.render(texture: inTexture, name: name, filter: filter)
        }
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            throw C7CustomError.commandBuffer
        }
        var outputTexture = outTexture
        if outputTexture == nil {
            let outputSize = filter.resize(input: C7Size(width: inTexture.width, height: inTexture.height))
            outputTexture = destTexture(width: outputSize.width, height: outputSize.height)
        }
        if case .compute(let kernel) = filter.modifier {
            guard let pipelineState = Compute.makeComputePipelineState(with: kernel) else {
                throw C7CustomError.computePipelineState(kernel)
            }
            var textures = [outputTexture!, inTexture]
            textures += filter.otherInputTextures
            Compute.drawingProcess(pipelineState, commandBuffer: commandBuffer, textures: textures, filter: filter)
        } else if case .render(let vertex, let fragment) = filter.modifier {
            guard let pipelineState = Rendering.makeRenderPipelineState(with: vertex, fragment: fragment) else {
                throw C7CustomError.renderPipelineState(vertex, fragment)
            }
            Rendering.drawingProcess(pipelineState, commandBuffer: commandBuffer, texture: inTexture, filter: filter)
        } else if case .mps(let performance) = filter.modifier {
            performance.encode(commandBuffer: commandBuffer, sourceTexture: inTexture, destinationTexture: outputTexture!)
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputTexture!
    }
    
    /// Create a texture for later storage according to the texture parameters.
    /// - Parameters:
    ///    - pixelformat: Indicates the pixelFormat, The format of the picture should be consistent with the data
    ///    - width: The texture width
    ///    - height: The texture height
    ///    - mipmapped: No mapping was required
    /// - Returns: New textures
    @inlinable static func destTexture(pixelFormat: MTLPixelFormat = MTLPixelFormat.rgba8Unorm,
                                       width: Int, height: Int,
                                       mipmapped: Bool = false) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: mipmapped)
        descriptor.usage = [.shaderRead, .shaderWrite]
        return Device.device().makeTexture(descriptor: descriptor)!
    }
}

//
//  C7FilterSerializer.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

public protocol C7FilterSerializer {
    
    /// Create a new texture based on the filter content.
    /// Please note that the order in which filters are added may affect the result of image generation.
    ///
    /// - Parameters:
    ///   - filters: Filter group, It must be an object implementing C7FilterProtocol
    /// - Returns: New texture after processing
    mutating func makeMTLTexture(filters: [C7FilterProtocol]) -> MTLTexture
    
    /// Filter processing
    /// - Parameters:
    ///   - filter: It must be an object implementing C7FilterProtocol
    /// - Returns: C7FilterSerializer
    mutating func makeImage<T: C7FilterSerializer>(filter: C7FilterProtocol) -> T
    
    /// Multiple filter combinations
    /// Please note that the order in which filters are added may affect the result of image generation.
    ///
    /// - Parameters:
    ///   - filters: Filter group, It must be an object implementing C7FilterProtocol
    /// - Returns: C7FilterSerializer
    mutating func makeGroup<T: C7FilterSerializer>(filters: [C7FilterProtocol]) -> T
}

extension C7FilterSerializer {
    /// Create a new texture based on the filter content.
    /// This protocol method does not need to be overridden unless you need to change the internal logic.
    ///
    /// - Parameters:
    ///   - intexture: Input texture
    ///   - otherTextures: Other input textures
    ///   - filter: It must be an object implementing C7FilterProtocol
    /// - Returns: New texture after processing
    func newTexture(inTexture: MTLTexture, otherTextures: C7InputTextures?, filter: C7FilterProtocol) -> MTLTexture {
        guard let commandBuffer = makeCommandBuffer() else {
            return inTexture
        }
        let outputSize = filter.outputSize(input: (inTexture.width, inTexture.height))
        let outTexture = destTexture(width: outputSize.width, height: outputSize.height)
        if case .compute(let kernel) = filter.modifier {
            var textures = [outTexture, inTexture]
            if let inTexture2 = otherTextures { textures += inTexture2 }
            let pipelineState = Compute.makeComputePipelineState(with: kernel)
            Compute.drawingProcess(pipelineState: pipelineState,
                                   commandBuffer: commandBuffer,
                                   textures: textures,
                                   factors: filter.factors)
        } else if case .render(let vertex, let fragment) = filter.modifier {
            var textures = [inTexture]
            if let inTexture2 = otherTextures { textures += inTexture2 }
            let pipelineState = Rendering.makeRenderPipelineState(with: vertex, fragment: fragment)
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

extension C7FilterSerializer {
    
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
        return Shared.shared.device!.device.makeTexture(descriptor: descriptor)!
    }
    
    /// Create command buffer.
    private func makeCommandBuffer() -> MTLCommandBuffer? {
        let commandBuffer = Shared.shared.device!.commandQueue.makeCommandBuffer()
        commandBuffer?.label = "QueenCommand"
        return commandBuffer
    }
}

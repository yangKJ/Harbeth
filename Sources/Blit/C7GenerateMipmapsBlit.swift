//
//  C7GenerateMipmapsBlit.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation
import MetalKit

/// 使用Blit操作生成纹理的mipmap
/// Generate mipmaps for the texture using Blit operation
public struct C7GenerateMipmapsBlit: C7FilterProtocol, BlitProtocol {
    
    public var modifier: ModifierEnum {
        return .blit
    }
    
    public init() { }
    
    public func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destTexture: MTLTexture) throws -> MTLTexture {
        // First, copy the source texture to the destination texture if they are different
        if sourceTexture !== destTexture {
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                throw HarbethError.makeBlitCommandEncoder
            }
            
            blitEncoder.copy(
                from: sourceTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1),
                to: destTexture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            
            blitEncoder.endEncoding()
        }
        
        // Generate mipmaps for the destination texture
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.makeBlitCommandEncoder
        }
        
        blitEncoder.generateMipmaps(for: destTexture)
        blitEncoder.endEncoding()
        
        return destTexture
    }
}

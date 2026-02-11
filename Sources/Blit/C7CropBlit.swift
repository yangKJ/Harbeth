//
//  C7CropBlit.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation
import MetalKit

/// 使用Blit操作裁剪纹理的特定区域
/// Crop a specific region of the texture using Blit operation
public struct C7CropBlit: C7FilterProtocol, BlitProtocol {
    
    public var modifier: ModifierEnum {
        return .blit
    }
    
    /// The crop rectangle in texture coordinates.
    private let rect: CGRect
    
    public init(rect: CGRect) {
        self.rect = rect
    }
    
    public func resize(input size: C7Size) -> C7Size {
        return C7Size(width: Int(rect.width), height: Int(rect.height))
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destTexture = textures[0], sourceTexture = textures[1]
        let x = Int(rect.origin.x)
        let y = Int(rect.origin.y)
        let width = Int(rect.width)
        let height = Int(rect.height)
        
        // Validate crop region
        guard x >= 0, y >= 0, x + width <= sourceTexture.width, y + height <= sourceTexture.height else {
            throw HarbethError.textureCropFailed
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.makeBlitCommandEncoder
        }
        
        blitEncoder.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: x, y: y, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: destTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        
        blitEncoder.endEncoding()
        return destTexture
    }
}

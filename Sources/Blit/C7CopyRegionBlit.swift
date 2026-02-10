//
//  C7CopyRegionBlit.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation
import MetalKit

/// 使用Blit操作复制纹理的特定区域到另一个位置
/// Copy a specific region of the texture to another location using Blit operation
public struct C7CopyRegionBlit: C7FilterProtocol, BlitProtocol {
    
    public var modifier: ModifierEnum {
        return .blit
    }
    
    /// The source rectangle to copy from.
    private let sourceRect: CGRect
    
    /// The destination origin to copy to.
    private let destOrigin: MTLOrigin
    
    public init(sourceRect: CGRect, destOrigin: MTLOrigin) {
        self.sourceRect = sourceRect
        self.destOrigin = destOrigin
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destTexture: MTLTexture) throws -> MTLTexture {
        let x = Int(sourceRect.origin.x)
        let y = Int(sourceRect.origin.y)
        let width = Int(sourceRect.width)
        let height = Int(sourceRect.height)
        
        // Validate source region
        guard x >= 0, y >= 0, x + width <= sourceTexture.width, y + height <= sourceTexture.height else {
            throw HarbethError.textureCropFailed
        }
        
        // Validate destination region
        guard destOrigin.x >= 0, destOrigin.y >= 0, 
              destOrigin.x + width <= destTexture.width, 
              destOrigin.y + height <= destTexture.height else {
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
            destinationOrigin: destOrigin
        )
        
        blitEncoder.endEncoding()
        return destTexture
    }
}

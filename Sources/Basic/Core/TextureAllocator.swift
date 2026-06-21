//
//  TextureAllocator.swift
//  Harbeth
//
//  Created by Codex on 2026/6/21.
//

import Foundation
import Metal

public protocol TextureAllocating: AnyObject {
    func dequeueTexture(width: Int,
                        height: Int,
                        pixelFormat: MTLPixelFormat,
                        allowsSizeTolerance: Bool) -> MTLTexture?
    func dequeueTextureLease(width: Int,
                             height: Int,
                             pixelFormat: MTLPixelFormat,
                             allowsSizeTolerance: Bool,
                             logicalExtent: C7Size?) -> TextureLease?
    func makeLease(for texture: MTLTexture, logicalExtent: C7Size?) -> TextureLease
    func enqueueTextureSync(_ texture: MTLTexture)
}

public final class TexturePoolAllocator: TextureAllocating {
    public let texturePool: TexturePool

    public init(texturePool: TexturePool) {
        self.texturePool = texturePool
    }

    public func dequeueTexture(width: Int,
                               height: Int,
                               pixelFormat: MTLPixelFormat,
                               allowsSizeTolerance: Bool = false) -> MTLTexture? {
        if allowsSizeTolerance {
            return texturePool.dequeueTexture(width: width, height: height, pixelFormat: pixelFormat)
        }
        return texturePool.dequeueExactTexture(width: width, height: height, pixelFormat: pixelFormat)
    }

    public func dequeueTextureLease(width: Int,
                                    height: Int,
                                    pixelFormat: MTLPixelFormat,
                                    allowsSizeTolerance: Bool = false,
                                    logicalExtent: C7Size? = nil) -> TextureLease? {
        texturePool.dequeueTextureLease(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: allowsSizeTolerance,
            logicalExtent: logicalExtent
        )
    }

    public func makeLease(for texture: MTLTexture, logicalExtent: C7Size? = nil) -> TextureLease {
        texturePool.makeLease(for: texture, logicalExtent: logicalExtent)
    }

    public func enqueueTextureSync(_ texture: MTLTexture) {
        texturePool.enqueueTextureSync(texture)
    }
}

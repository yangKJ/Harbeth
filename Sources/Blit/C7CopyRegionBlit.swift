//
//  C7CopyRegionBlit.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation
import MetalKit

/// 复制纹理的特定区域到另一个位置
/// Copy a specific region of the texture to another location using Blit operation
public struct C7CopyRegionBlit: C7FilterProtocol, BlitProtocol {
    
    public var modifier: ModifierEnum {
        return .blit
    }
    
    public var needCreateDestTexture: Bool = false

    public var destinationTextureContract: FilterDestinationTextureContract {
        .init(aliasingPolicy: .inPlaceAllowed)
    }
    
    /// The source rectangle to copy from.
    private let sourceRect: CGRect?
    
    /// The destination origin to copy to.
    private let destOrigin: MTLOrigin
    
    public init(sourceRect: CGRect? = nil, destOrigin: MTLOrigin) {
        self.sourceRect = sourceRect
        self.destOrigin = destOrigin
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let destTexture = textures[0], sourceTexture = textures[1]
        let sourceRect = sourceRect ?? CGRect(x: 0, y: 0, width: sourceTexture.width, height: sourceTexture.height)
        guard let region = TextureRegionRect(rect: sourceRect),
              region.fits(in: sourceTexture),
              region.fits(at: destOrigin, in: destTexture) else {
            throw HarbethError.textureCropFailed
        }

        if sourceTexture === destTexture,
           region.x == destOrigin.x,
           region.y == destOrigin.y {
            return destTexture
        }

        if sharesStorage(sourceTexture, destTexture) {
            return try encodeAliasedCopy(
                commandBuffer: commandBuffer,
                sourceTexture: sourceTexture,
                destinationTexture: destTexture,
                region: region
            )
        }

        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.makeBlitCommandEncoder
        }
        
        blitEncoder.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: region.x, y: region.y, z: 0),
            sourceSize: MTLSize(width: region.width, height: region.height, depth: 1),
            to: destTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: destOrigin
        )
        
        blitEncoder.endEncoding()
        return destTexture
    }

    private func encodeAliasedCopy(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture,
        region: TextureRegionRect
    ) throws -> MTLTexture {
        let stagingTexture = try TextureLoader.makeTexture(
            width: region.width,
            height: region.height,
            options: [
                .texturePixelFormat: sourceTexture.pixelFormat,
                .textureUsage: MTLTextureUsage.shaderRead.union(.shaderWrite)
            ],
            identifier: "C7CopyRegionBlit.AliasStaging"
        )
        var recyclesOnFailure = true
        defer {
            if recyclesOnFailure {
                HarbethContext.shared.texturePool.enqueueTextureSync(stagingTexture)
            }
        }

        guard let stageEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.makeBlitCommandEncoder
        }
        stageEncoder.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: region.x, y: region.y, z: 0),
            sourceSize: MTLSize(width: region.width, height: region.height, depth: 1),
            to: stagingTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        stageEncoder.endEncoding()

        guard let destinationEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw HarbethError.makeBlitCommandEncoder
        }
        destinationEncoder.copy(
            from: stagingTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: region.width, height: region.height, depth: 1),
            to: destinationTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: destOrigin
        )
        destinationEncoder.endEncoding()

        let transfer = HarbethUncheckedTransfer(value: stagingTexture)
        commandBuffer.addCompletedHandler { _ in
            HarbethContext.shared.texturePool.enqueueTextureSync(transfer.value)
        }
        recyclesOnFailure = false
        return destinationTexture
    }

    private func sharesStorage(_ lhs: MTLTexture, _ rhs: MTLTexture) -> Bool {
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
}

//
//  C7FilterImage.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

extension C7Image: C7Compatible { }

/// 以下模式均只支持基于并行计算编码器`compute(kernel: String)`
/// The following modes support only the encoder based on parallel computing
///
extension C7Image: C7FilterOutput {
    
    public func make<T>(filter: C7FilterProtocol) throws -> T where T : C7FilterOutput {
        guard let inTexture = self.mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            let otherTextures = filter.otherInputTextures
            let outTexture = try newTexture(inTexture: inTexture, otherTextures: otherTextures, filter: filter)
            guard let outImage = outTexture.toImage() else {
                throw C7CustomError.texture2Image
            }
            return outImage as! T
        } catch {
            throw error
        }
    }
    
    public func makeGroup<T>(filters: [C7FilterProtocol]) throws -> T where T : C7FilterOutput {
        guard let inTexture = self.mt.toTexture() else {
            throw C7CustomError.source2Texture
        }
        do {
            var outTexture: MTLTexture = inTexture
            for filter in filters {
                let otherTextures = filter.otherInputTextures
                outTexture = try newTexture(inTexture: outTexture, otherTextures: otherTextures, filter: filter)
            }
            return (outTexture.toImage() ?? self) as! T
        } catch {
            throw error
        }
    }
}

extension Queen where Base == C7Image {
    public func toTexture() -> MTLTexture? {
        guard let cgimage = base.cgImage else { return nil }
        let loader = Shared.shared.device!.textureLoader
        return try? loader.newTexture(cgImage: cgimage, options: [MTKTextureLoader.Option.SRGB : false])
    }
}

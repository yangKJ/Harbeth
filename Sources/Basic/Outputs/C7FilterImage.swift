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
extension C7Image: C7FilterSerializer {
    public func makeMTLTexture(filters: [C7FilterProtocol]) throws -> MTLTexture {
        guard let inTexture = self.mt.toTexture() else {
            throw C7CustomError.image2Texture
        }
        var outTexture: MTLTexture = inTexture
        for filter in filters {
            let otherTextures = filter.otherInputTextures
            outTexture = newTexture(inTexture: outTexture, otherTextures: otherTextures, filter: filter)
        }
        return outTexture
    }
    
    public func makeImage<T>(filter: C7FilterProtocol) -> T where T : C7FilterSerializer {
        guard let inTexture = self.mt.toTexture() else {
            return self as! T
        }
        let otherTextures = filter.otherInputTextures
        let outTexture = newTexture(inTexture: inTexture, otherTextures: otherTextures, filter: filter)
        return (outTexture.toImage() ?? self) as! T
    }
    
    public func makeGroup<T>(filters: [C7FilterProtocol]) -> T where T : C7FilterSerializer {
        guard let inTexture = self.mt.toTexture() else {
            return self as! T
        }
        var outTexture: MTLTexture = inTexture
        for filter in filters {
            let otherTextures = filter.otherInputTextures
            outTexture = newTexture(inTexture: outTexture, otherTextures: otherTextures, filter: filter)
        }
        return (outTexture.toImage() ?? self) as! T
    }
}

extension Queen where Base == C7Image {
    public func toTexture() -> MTLTexture? {
        guard let cgimage = base.cgImage else { return nil }
        let loader = Shared.shared.device!.textureLoader
        return try? loader.newTexture(cgImage: cgimage, options: [MTKTextureLoader.Option.SRGB : false])
    }
}

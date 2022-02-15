//
//  C7FilterImage.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit
import class UIKit.UIImage

public typealias C7Image = UIImage

extension C7Image: C7Compatible { }

/// 以下模式均只支持基于并行计算编码器`compute(kernel: String)`
/// The following modes support only the encoder based on parallel computing
///
extension C7Image: C7FilterSerializer {
    
    public func makeMTLTexture(filters: [C7FilterProtocol]) -> MTLTexture {
        guard let inTexture = self.mt.toTexture() else {
            fatalError("Input image transform texture failed.")
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
        do {
            let loader = Device.shared.textureLoader
            let options = [MTKTextureLoader.Option.SRGB : false]
            let texture = try loader.newTexture(cgImage: base.cgImage!, options: options)
            return texture
        } catch {
            fatalError("Failed loading image texture")
        }
    }
}

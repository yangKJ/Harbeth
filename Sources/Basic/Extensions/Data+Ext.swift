//
//  Data+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/27.
//

import Foundation
import MetalKit

extension Data: C7Compatible { }

extension Queen where Base == Data {
    
    /// Image data to texture
    ///
    /// Texture loader can not load image data to create texture
    /// If image orientation is not up, texture loader may not load texture from image data.
    /// Create a UIImage from image data to get metal texture
    /// Draw image and create texture
    /// - Parameter options: Dictonary of MTKTextureLoaderOptions
    /// - Returns: MTLTexture
    public func toTexture(options: [MTKTextureLoader.Option: Any]? = nil) -> MTLTexture? {
        let usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
        let options: [MTKTextureLoader.Option: Any] = options ?? [
            .textureUsage: NSNumber(value: usage.rawValue),
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false)
        ]
        let loader = Shared.shared.device?.textureLoader
        if let texture = try? loader?.newTexture(data: base, options: options) {
            return texture
        }
        return C7Image.init(data: base)?.mt.toTexture()
    }
}

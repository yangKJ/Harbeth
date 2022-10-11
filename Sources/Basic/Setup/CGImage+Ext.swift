//
//  CGImage+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/9.
//

import Foundation
import MetalKit
import CoreGraphics

extension CGImage: C7Compatible { }

extension Queen where Base: CGImage {
    
    /// CGImage to texture
    ///
    /// Texture loader can not load image data to create texture
    /// Draw image and create texture
    /// - Parameter pixelFormat: Indicates the pixelFormat, The format of the picture should be consistent with the data.
    /// - Returns: MTLTexture
    public func toTexture(pixelFormat: MTLPixelFormat = .rgba8Unorm) -> MTLTexture? {
        let width = base.width, height = base.height
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = pixelFormat
        descriptor.width  = width
        descriptor.height = height
        descriptor.usage  = [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]
        guard let currentTexture = Device.device().makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        let bytesPerPixel: Int = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = Device.bitmapInfo(base)
        let colorSpace = Device.colorSpace(base)
        let context = CGContext(data: nil, width: width, height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)
        context?.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        if let data = context?.data {
            let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
            currentTexture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
            return currentTexture
        }
        return nil
    }
    
    /// Creates a new Metal texture from a given bitmap image.
    /// - Parameter options: Dictonary of MTKTextureLoaderOptions
    /// - Returns: MTLTexture
    public func newTexture(options: [MTKTextureLoader.Option: Any]? = nil) -> MTLTexture? {
        let usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
        let textureOptions: [MTKTextureLoader.Option: Any] = options ?? [
            .textureUsage: NSNumber(value: usage.rawValue),
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false)
        ]
        let loader = Shared.shared.device?.textureLoader
        return try? loader?.newTexture(cgImage: base, options: textureOptions)
    }
}

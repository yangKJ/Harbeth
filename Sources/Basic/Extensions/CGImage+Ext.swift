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
        let bitmapInfo = Device.bitmapInfo()
        let colorSpace = Device.colorSpace()
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
    
    public func toC7Image() -> C7Image {
        #if os(iOS) || os(tvOS) || os(watchOS)
        return C7Image.init(cgImage: base)
        #elseif os(macOS)
        return C7Image.init(cgImage: base, size: base.mt.size)
        #else
        #error("Unsupported Platform")
        #endif
    }
}

extension Queen where Base: CGImage {
    
    #if os(iOS) || os(tvOS) || os(watchOS)
    public var size: CGSize {
        CGSize(width: base.width, height: base.height)
    }
    #elseif os(macOS)
    public var size: NSSize {
        NSSize(width: base.width, height: base.height)
    }
    #endif
    
    public func swapRedAndGreenAmount(context: CIContext? = nil) -> CGImage {
        let ctx = context ?? Device.context(cgImage: base)
        let ciImage = CIImage(cgImage: base)
        let source = "kernel vec4 swapRedAndGreenAmount(__sample s) { return s.bgra; }"
        let swapKernel = CIColorKernel(source: source)
        if let ciOutput = swapKernel?.apply(extent: ciImage.extent, arguments: [ciImage as Any]) {
            return ctx.createCGImage(ciOutput, from: ciImage.extent) ?? base
        }
        return base
    }
}

//
//  MTQTransform.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import MetalKit
import ImageIO

extension MTQImage: MTQCompatible { }

extension Queen where Base: MTQImage {
    public func toTexture() -> MTLTexture? {
        do {
            let loader = RenderingDevice.shared.textureLoader
            let options = [MTKTextureLoader.Option.SRGB : false]
            let texture = try loader.newTexture(cgImage: base.cgImage!, options: options)
            return texture
        } catch {
            fatalError("Failed loading image texture")
        }
    }
}

extension MTLTexture {
    public func toCGImage() -> CGImage? {
        let bytesPerPixel: Int = 4
        let imageByteCount = width * height * bytesPerPixel
        let bytesPerRow = width * bytesPerPixel
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
        self.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        //kCGImageAlphaPremultipliedLast保留透明度
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let colorSpace = RenderingDevice.shared.colorSpace//CGColorSpaceCreateDeviceRGB()
        
        let bitsPerComponent = 8
        let context = CGContext(data: &src,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)

        guard let context = context else { return nil }
        return context.makeImage()
    }
    
    public func toImage() -> MTQImage? {
        guard let cgImage = toCGImage() else {
            return nil
        }
        return MTQImage(cgImage: cgImage)
    }
}

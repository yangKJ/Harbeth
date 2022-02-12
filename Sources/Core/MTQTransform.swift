//
//  MTQTransform.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import MetalKit
import ImageIO
import UIKit

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
    
    /// 将像素数据对象复制到纹理
    /// - Parameter texture: 纹理
    public func replaceRegion(_ texture: MTLTexture) {
        //let width  = Int(base.size.width)
        //let height = Int(base.size.height)
        //let bytesPerRow = 4 * width
        //let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
        //var src = [UInt8](repeating: 0, count: Int(width * height * 4))
        //texture.replace(region: region, mipmapLevel: 0, withBytes: &src, bytesPerRow: bytesPerRow)
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
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
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
        return MTQImage(cgImage: cgImage)//, scale: 0.0, orientation: MTQImage.Orientation.downMirrored)
    }
}

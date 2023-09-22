//
//  CGImage+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/9.
//

import Foundation
import MetalKit
import CoreGraphics
import CoreVideo

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
        let bytesPerPixel: Int = 4
        let bytesPerRow = width * bytesPerPixel
        let context = CGContext(data: nil, width: width, height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: Device.colorSpace(),
                                bitmapInfo: Device.bitmapInfo())
        context?.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context?.data else {
            return nil
        }
        guard let texture = try? TextureLoader.emptyTexture(width: width, height: height, options: [
            .texturePixelFormat: pixelFormat
        ]) else {
            return nil
        }
        let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
        return texture
    }
    
    public func toPixelBuffer() -> CVPixelBuffer? {
        let imageWidth  = Int(base.width)
        let imageHeight = Int(base.height)
        let attributes: [NSObject:AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as CFNumber,
            kCVPixelBufferCGImageCompatibilityKey : true as AnyObject,
            kCVPixelBufferCGBitmapContextCompatibilityKey : true as AnyObject,
            kCVPixelBufferMetalCompatibilityKey: true as AnyObject,
        ]
        var pxbuffer: CVPixelBuffer? = nil
        CVPixelBufferCreate(kCFAllocatorDefault,
                            imageWidth,
                            imageHeight,
                            kCVPixelFormatType_32BGRA,
                            attributes as CFDictionary?,
                            &pxbuffer)
        guard let pxbuffer = pxbuffer else {
            return nil
        }
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pxbuffer, flags) else {
            return nil
        }
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pxbuffer),
                                width: imageWidth,
                                height: imageHeight,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pxbuffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        if let context = context {
            context.draw(base, in: CGRect.init(x: 0, y: 0, width: imageWidth, height: imageHeight))
        } else {
            CVPixelBufferUnlockBaseAddress(pxbuffer, flags);
            return nil
        }
        CVPixelBufferUnlockBaseAddress(pxbuffer, flags);
        return pxbuffer
    }
    
    public func toImage() -> C7Image {
        toC7Image()
    }
    
    public func toC7Image() -> C7Image {
        #if os(iOS) || os(tvOS) || os(watchOS)
        return UIImage.init(cgImage: base)
        #elseif os(macOS)
        return NSImage(cgImage: base, size: .init(width: base.width, height: base.height))
        #else
        #error("Unsupported Platform")
        #endif
    }
}

extension Queen where Base: CGImage {
    
    public var hasAlphaChannel: Bool {
        switch base.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
    
    #if os(iOS) || os(tvOS) || os(watchOS)
    public var size: CGSize {
        CGSize(width: base.width, height: base.height)
    }
    #elseif os(macOS)
    public var size: NSSize {
        NSSize(width: base.width, height: base.height)
    }
    #endif
}

extension Queen where Base: CGImage {
    
    /// Crop the picture to the specified proportion, and the excess will be automatically deleted.
    /// - Parameter ratio: Cutting ratio.
    public func cropping(ratio: CGFloat) -> CGImage {
        if ratio <= 0 { return base }
        let width  = CGFloat(base.width)
        let height = CGFloat(base.height)
        let size: CGSize
        if width / height > ratio {
            size = CGSize(width: height * ratio, height: height)
        } else {
            size = CGSize(width: width, height: width / ratio)
        }
        let x = abs((size.width - width ) / 2.0)
        let y = abs((size.height - height ) / 2.0)
        let rect = CGRect(origin: .init(x: x, y: y), size: size)
        let finalImageRef = base.cropping(to: rect)
        return finalImageRef ?? base
    }
    
    /// Crop the edge area
    /// - Parameter space: Crop the edge area.
    public func cropping(space: CGFloat) -> CGImage {
        let width  = CGFloat(base.width)
        let height = CGFloat(base.height)
        let rect = CGRect(x: space, y: space, width: width-2*space, height: height-2*space)
        let finalImageRef = base.cropping(to: rect)
        return finalImageRef ?? base
    }
}

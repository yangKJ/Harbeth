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

extension CGImage: HarbethCompatible { }

extension HarbethWrapper where Base: CGImage {
    
    /// Check if the image has an alpha channel
    public var hasAlphaChannel: Bool {
        switch base.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
    
    #if os(macOS)
    public var size: NSSize {
        NSSize(width: base.width, height: base.height)
    }
    #else
    public var size: CGSize {
        CGSize(width: base.width, height: base.height)
    }
    #endif
    
    /// Convert CGImage to MTLTexture
    /// - Parameter pixelFormat: Target pixel format for the texture
    /// - Returns: Created MTLTexture or nil if conversion fails
    public func toTexture(pixelFormat: MTLPixelFormat = .rgba8Unorm) -> MTLTexture? {
        let width = base.width, height = base.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        // Create context with optimized parameters
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: Device.colorSpace(),
                                      bitmapInfo: Device.bitmapInfo()) else {
            return nil
        }
        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data,
              let texture = try? TextureLoader.makeTexture(width: width, height: height, options: [
                .texturePixelFormat: pixelFormat
              ]) else {
            return nil
        }
        let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
        return texture
    }
    
    /// Convert CGImage to CVPixelBuffer for video processing
    /// - Returns: Created CVPixelBuffer or nil if conversion fails
    public func toPixelBuffer() -> CVPixelBuffer? {
        let imageWidth = Int(base.width), imageHeight = Int(base.height)
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        var pxbuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, imageWidth, imageHeight,
            kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pxbuffer
        )
        guard status == kCVReturnSuccess, let buffer = pxbuffer else {
            return nil
        }
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard CVPixelBufferLockBaseAddress(buffer, flags) == kCVReturnSuccess else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, flags) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        let context = CGContext(data: baseAddress, width: imageWidth, height: imageHeight,
                                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        context?.draw(base, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        return buffer
    }
    
    /// Convert CGImage to platform-specific image (UIImage/NSImage)
    public func toImage() -> C7Image {
        toC7Image()
    }
    
    public func toC7Image() -> C7Image {
        #if os(macOS)
        return NSImage(cgImage: base, size: CGSize(width: base.width, height: base.height))
        #else
        return UIImage(cgImage: base)
        #endif
    }
    
    /// Create image with reference image's scale and orientation
    public func drawing(refImage: C7Image) -> C7Image {
        #if os(macOS)
        let width = CGFloat(base.width) * refImage.scale
        let height = CGFloat(base.height) * refImage.scale
        return NSImage(cgImage: base, size: CGSize(width: width, height: height))
        #else
        return UIImage(cgImage: base, scale: refImage.scale, orientation: refImage.imageOrientation)
        #endif
    }
}

extension HarbethWrapper where Base: CGImage {
    
    /// Crop image to specified aspect ratio, removing excess parts
    /// - Parameter ratio: Target aspect ratio (width/height)
    /// - Returns: Cropped CGImage
    public func cropping(ratio: CGFloat) -> CGImage {
        guard ratio > 0 else { return base }
        let width = CGFloat(base.width), height = CGFloat(base.height)
        let size: CGSize
        if width / height > ratio {
            size = CGSize(width: height * ratio, height: height)
        } else {
            size = CGSize(width: width, height: width / ratio)
        }
        let x = abs((size.width - width) / 2.0)
        let y = abs((size.height - height) / 2.0)
        let rect = CGRect(x: x, y: y, width: size.width, height: size.height)
        return base.cropping(to: rect) ?? base
    }
    
    /// Crop edges by specified amount
    /// - Parameter space: Amount to crop from each edge
    /// - Returns: Cropped CGImage
    public func cropping(space: CGFloat) -> CGImage {
        let width = CGFloat(base.width), height = CGFloat(base.height)
        let rect = CGRect(x: space, y: space, width: width - 2 * space, height: height - 2 * space)
        return base.cropping(to: rect) ?? base
    }
    
    /// Calculate transformation matrix to fix image orientation
    /// - Parameter orientation: Target image orientation
    /// - Returns: CGAffineTransform for correction
    public func fixTransform(from orientation: C7ImageOrientation) -> CGAffineTransform {
        let width = CGFloat(base.width), height = CGFloat(base.height)
        var transform = CGAffineTransform.identity
        switch orientation {
        case .down, .downMirrored:
            transform = CGAffineTransform(translationX: width, y: height).rotated(by: .pi)
        case .left, .leftMirrored:
            transform = CGAffineTransform(translationX: width, y: 0).rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = CGAffineTransform(translationX: 0, y: height).rotated(by: -.pi / 2)
        default:
            break
        }
        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0).scaledBy(x: -1, y: 1)
        default:
            break
        }
        return transform
    }
    
    /// Fix image orientation using transformation
    /// - Parameter orientation: Target orientation
    /// - Returns: Corrected CGImage
    public func fixOrientation(from orientation: C7ImageOrientation) -> CGImage {
        guard let colorSpace = base.colorSpace else {
            return base
        }
        let width = CGFloat(base.width), height = CGFloat(base.height)
        let transform = base.c7.fixTransform(from: orientation)
        let context = CGContext(data: nil,
                                width: Int(width),
                                height: Int(height),
                                bitsPerComponent: base.bitsPerComponent,
                                bytesPerRow: 0,
                                space: colorSpace,
                                bitmapInfo: base.bitmapInfo.rawValue)
        context?.concatenate(transform)
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context?.draw(base, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context?.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return context?.makeImage() ?? base
    }
}

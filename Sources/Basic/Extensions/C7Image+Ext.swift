//
//  Transform.swift
//  Harbeth
//
//  Created by Condy on 2022/2/28.
//

import Foundation
import MetalKit
import CoreImage
import CoreVideo
#if !os(macOS)
import MobileCoreServices
#endif

extension C7Image: HarbethCompatible { }

extension HarbethWrapper where Base: C7Image {
    
    /// Image to texture
    ///
    /// Texture loader can not load image data to create texture
    /// Draw image and create texture
    /// - Returns: MTLTexture
    public func toTexture(cgimage: CGImage? = nil) -> MTLTexture? {
        guard let cgImage = cgimage ?? base.cgImage else {
            return nil
        }
        return try? TextureLoader.init(with: cgImage).texture
    }
    
    public func toCIImage() -> CIImage? {
        #if os(iOS) || os(tvOS) || os(watchOS)
        if let ciImage = base.ciImage {
            return ciImage
        }
        return CIImage(image: base)
        #else
        if let cgImage = base.cgImage {
            return CIImage(cgImage: cgImage)
        }
        return nil
        #endif
    }
    
    #if canImport(UIKit) && !os(watchOS)
    public func toPixelBuffer() -> CVPixelBuffer? {
        let width = base.size.width
        let height = base.size.height
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(width),
                                         Int(height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs,
                                         &pixelBuffer)
        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }
        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)
        UIGraphicsPushContext(context)
        base.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return resultPixelBuffer
    }
    #endif
    
    /// Change the color of the picture.
    /// - Parameter color: Change the color.
    /// - Returns: The changed image.
    public func tinted(color: C7Color) -> C7Image {
        #if os(iOS) || os(tvOS) || os(watchOS)
        UIGraphicsBeginImageContextWithOptions(base.size, false, base.scale)
        color.setFill()
        let bounds = CGRect.init(origin: .zero, size: base.size)
        UIRectFill(bounds)
        base.draw(in: bounds, blendMode: CGBlendMode.destinationIn, alpha: 1.0)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage ?? base
        #elseif os(macOS)
        let imageRect = NSRect.init(origin: .zero, size: base.size)
        return NSImage.init(size: base.size, flipped: false) { (rect) -> Bool in
            color.set()
            rect.fill()
            base.draw(in: rect, from: imageRect, operation: .destinationIn, fraction: 1.0)
            return true
        }
        #else
        return base
        #endif
    }
    
    public func tiffData() -> Data? {
        #if os(macOS)
        return base.tiffRepresentation
        #else
        guard let cgImage = base.cgImage else {
            return nil
        }
        let options: NSDictionary = [
            kCGImagePropertyOrientation: base.imageOrientation,
            kCGImagePropertyHasAlpha: true
        ]
        let data = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(data as CFMutableData, kUTTypeTIFF, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(imageDestination, cgImage, options)
        CGImageDestinationFinalize(imageDestination)
        return data as Data        
        #endif
    }
    
    /// 渲染图像，如果中间涉及到Context，则还是需要用`UIGraphicsBeginImageContextWithOptions`
    /// - Parameters:
    ///   - rect: Rect for drawing images.
    ///   - canvas: Canvas size.
    ///   - scale: Image scale.
    public func renderer(rect: CGRect, canvas: CGSize, scale: CGFloat? = nil) -> C7Image {
        if canvas.width <= 0 || canvas.height <= 0 {
            return base
        }
        #if os(iOS) || os(tvOS) || os(watchOS)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale ?? base.scale
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        let result = renderer.image { _ in base.draw(in: rect) }
        return result
        #elseif os(macOS)
        let result = NSImage(size: canvas)
        result.lockFocus()
        let destRect = CGRect(origin: .zero, size: result.size)
        base.draw(in: destRect, from: .zero, operation: .sourceOver, fraction: scale ?? base.scale)
        result.unlockFocus()
        return result
        #else
        return base
        #endif
    }
}

// MARK: - edit image
extension HarbethWrapper where Base: C7Image {
    /// Resize an image to the specified size. Depending on what fitMode is supplied.
    /// Note: The display control contentMode must be `.scaleAspectFit`.
    /// - Parameters:
    ///   - size: Size to resize the image to. it is zero will return itseff.
    ///   - mode: Mainly for the image filling content to change the size.
    /// - Returns: Resized image.
    public func resized(with size: CGSize, mode: ResizingMode) -> C7Image {
        mode.resizeImage(base, size: size)
    }
    
    /// Modify image size.
    /// - Parameters:
    ///   - size: Target size.
    ///   - equalRatio: Whether to use the original image ratio.
    ///   - scale: Image scale.
    /// - Returns: Return a new image.
    public func zipScale(size: CGSize, equalRatio: Bool = false, scale: CGFloat? = nil) -> C7Image {
        if __CGSizeEqualToSize(base.size, size) { return base }
        let rect: CGRect
        if size.width / size.height != base.size.width / base.size.height && equalRatio {
            var sh = size.width / base.size.width * base.size.height
            var sw = size.width
            if sh < size.height {
                sw = size.height / sh * size.width
                sh = size.height
            }
            rect = CGRect(x: -(sw - size.height) * 0.5, y: -(sh - size.height) * 0.5, width: sw, height: sh)
        } else {
            rect = CGRect(origin: .zero, size: size)
        }
        return base.c7.renderer(rect: rect, canvas: rect.size, scale: scale)
    }
    
    /// Adjust the gap around the image.
    /// - Parameter padding: around padding.
    /// - Returns: Return a new image.
    public func withPadding(_ padding: C7EdgeInsets) -> C7Image {
        let width = base.size.width + padding.left + padding.right
        let height = base.size.height + padding.top + padding.bottom
        let rect = CGRectMake(padding.left, padding.top, base.size.width, base.size.height)
        return base.c7.renderer(rect: rect, canvas: .init(width: width, height: height))
    }
    
    /// Crop the picture to the specified proportion, and the excess will be automatically deleted.
    /// - Parameter ratio: Cutting ratio.
    public func crop(ratio: CGFloat) -> C7Image {
        if ratio <= 0 { return base }
        let width  = base.size.width
        let height = base.size.height
        let size: CGSize
        if width / height > ratio {
            size = CGSize(width: height * ratio, height: height)
        } else {
            size = CGSize(width: width, height: width / ratio)
        }
        let rect = CGRectMake((size.width - width ) / 2.0, (size.height - height ) / 2.0, width, height)
        return base.c7.renderer(rect: rect, canvas: size)
    }
    
    /// Crop the edge area.
    /// - Parameter space: Edge pixel size.
    public func crop(space: CGFloat) -> C7Image {
        let size = base.size
        let rect = CGRect(x: -space, y: -space, width: size.width+2*space, height: size.height+2*space)
        return base.c7.renderer(rect: rect, canvas: size)
    }
}

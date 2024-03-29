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
    
    public func toCGImage() -> CGImage? {
        #if os(macOS)
        return base.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return base.cgImage
        #endif
    }
    
    public func toCIImage() -> CIImage? {
        #if os(macOS)
        if let cgImage = base.cgImage {
            return CIImage(cgImage: cgImage)
        }
        return nil
        #else
        if let ciImage = base.ciImage {
            return ciImage
        }
        return CIImage(image: base)
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
        #if os(macOS)
        let imageRect = NSRect.init(origin: .zero, size: base.size)
        return NSImage.init(size: base.size, flipped: false) { (rect) -> Bool in
            color.set()
            rect.fill()
            base.draw(in: rect, from: imageRect, operation: .destinationIn, fraction: base.scale)
            return true
        }
        #else
        UIGraphicsBeginImageContextWithOptions(base.size, false, base.scale)
        color.setFill()
        let bounds = CGRect.init(origin: .zero, size: base.size)
        UIRectFill(bounds)
        base.draw(in: bounds, blendMode: CGBlendMode.destinationIn, alpha: 1.0)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage ?? base
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
    
    /// Render image with rect, scale and inverting.
    /// - Parameters:
    ///   - rect: Rect for drawing images.
    ///   - canvas: Canvas size, If it is empty, rect size is used.
    ///   - scale: Image scale.
    ///   - inverting: If drawing a CGImage, we need to make context flipped.
    ///   - isOpaque: Whether it is opaque.
    ///   - drawContext: Changed renderer context, Only available on ios.
    /// - Returns: Renderered image.
    public func renderer(
        rect: CGRect,
        canvas: CGSize? = nil,
        scale: CGFloat? = nil,
        inverting: Bool = false,
        isOpaque: Bool = true,
        drawContext: ((CGContext) -> Void)? = nil
    ) -> C7Image {
        let canvas = {
            if let canvas = canvas, canvas.width > 0, canvas.height > 0 {
                return canvas
            }
            return rect.size
        }()
        #if os(macOS)
        let result = NSImage(size: canvas)
        result.lockFocus()
        let destRect = CGRect(origin: .zero, size: result.size)
        if inverting {
            result.c7.flip(horizontal: true, vertical: true)
        }
        base.draw(in: destRect, from: .zero, operation: .sourceOver, fraction: scale ?? base.scale)
        result.unlockFocus()
        return result
        #else
        let format: UIGraphicsImageRendererFormat
        if #available(iOS 11.0, *) {
            format = UIGraphicsImageRendererFormat.preferred()
        } else {
            format = UIGraphicsImageRendererFormat.default()
        }
        format.scale = scale ?? base.scale
        format.opaque = isOpaque
        let render = UIGraphicsImageRenderer(size: canvas, format: format)
        return render.image { rendererContext in
            let context = rendererContext.cgContext
            if inverting {
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: 0, y: -canvas.height)
            }
            drawContext?(context)
            base.draw(in: rect)
        }
        #endif
    }
    
    /// Fixed an issue with HEIC flipping after adding filter.
    /// Make context flipped.
    public func inverting() -> C7Image {
        renderer(rect: .init(origin: .zero, size: base.size), inverting: true)
    }
    
    /// To ensure image orientation is correct, redraw image if image orientation is not up.
    /// See: https://stackoverflow.com/questions/42098390/swift-png-image-being-saved-with-incorrect-orientation
    public func flattened(isOpaque: Bool = true) -> C7Image {
        #if os(macOS)
        //return base.c7.revolve180
        return base
        #else
        if base.imageOrientation == .up {
            return base
        }
        return base.c7.renderer(rect: .init(origin: .zero, size: base.size), isOpaque: isOpaque)
        #endif
    }
    
    /// Fixed image rotation direction.
    public func fixOrientation() -> C7Image {
        #if os(macOS)
        return base
        #else
        guard base.imageOrientation != .up, let cgImage = base.cgImage else {
            return base
        }
        return cgImage.c7.drawing(refImage: base)
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
    public func resized(with size: CGSize, mode: Harbeth.ResizingMode) -> C7Image {
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
    
    /// Rotate the picture.
    /// - Parameter degrees: Rotation angle.
    /// - Returns: The picture after rotation.
    public func rotate(degrees: Float) -> C7Image {
        #if os(macOS)
        let img = NSImage(size: base.size, flipped: false, drawingHandler: { (rect) -> Bool in
            let (width, height) = (rect.size.width, rect.size.height)
            let transform = NSAffineTransform()
            transform.translateX(by: width / 2, yBy: height / 2)
            transform.rotate(byDegrees: CGFloat(degrees))
            transform.translateX(by: -width / 2, yBy: -height / 2)
            transform.concat()
            base.draw(in: rect)
            return true
        })
        img.isTemplate = base.isTemplate // preserve the underlying image's template setting
        return img
        #else
        let radians = CGFloat(degrees) / 180.0 * .pi
        let tran = CGAffineTransform(rotationAngle: radians)
        var size = CGRect(origin: .zero, size: base.size).applying(tran).size
        size.width  = floor(size.width)
        size.height = floor(size.height)
        let rect = CGRect(x: -base.size.width/2, y: -base.size.height/2, width: base.size.width, height: base.size.height)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: size.width/2, y: size.height/2)
        context?.rotate(by: radians)
        base.draw(in: rect)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? base
        #endif
    }
    
    /// Rotation 180.
    public var revolve180: C7Image {
        #if os(macOS)
        //return NSImage(size: base.size, flipped: true, drawingHandler: { _ in true })
        return rotate(degrees: 180)
        #else
        guard let cgImage = base.cgImage else {
            return base
        }
        return C7Image(cgImage: cgImage, scale: base.scale, orientation: .down)
        #endif
    }
}

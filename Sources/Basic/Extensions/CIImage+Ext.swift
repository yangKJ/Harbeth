//
//  CIImage+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/11.
//

import Foundation
import MetalKit

extension CIImage: HarbethCompatible { }

extension HarbethWrapper where Base: CIImage {
    
    public func toCGImage(context: CIContext? = nil) -> CGImage? {
        if let cgImage = base.cgImage {
            return cgImage
        }
        let context = context ?? Device.context(colorSpace: Device.colorSpace())
        guard let cgImage = context.createCGImage(base, from: base.extent) else {
            return nil
        }
        return cgImage
    }
    
    public func toImage() -> C7Image? {
        if let cgImage = base.cgImage {
            return C7Image(cgImage: cgImage, scale: 1.0, orientation: .up)
        } else {
            #if os(macOS)
            return nil
            #else
            return C7Image(ciImage: base, scale: 1.0, orientation: .up)
            #endif
        }
    }
    
    /// Fixed image horizontal flip problem.
    public func fixHorizontalFlip() -> CIImage {
        return base.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
            .transformed(by: CGAffineTransform(translationX: 0, y: base.extent.height))
    }
    
    /// Write CIImage to metal texture, and then wait for final submission.
    /// Render bounds of CIImage to a Metal texture, optionally specifying what command buffer to use.
    /// - Parameters:
    ///   - texture: Output the texture and write CIImage to the metal texture.
    ///   - commandBuffer: A valid MTLCommandBuffer to receive the encoded filter.
    public func renderCIImageToTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let ctx = Device.context(colorSpace: Device.colorSpace())
        let img = fixHorizontalFlip()
        if #available(iOS 11.0, macOS 10.13, *) {
            let renderDestination = CIRenderDestination(mtlTexture: texture, commandBuffer: commandBuffer)
            //try ctx.prepareRender(img, from: img.extent, to: renderDestination, at: .zero)
            _ = try ctx.startTask(toRender: img, to: renderDestination)
        } else {
            ctx.render(img, to: texture, commandBuffer: commandBuffer, bounds: img.extent, colorSpace: Device.colorSpace())
        }
    }
    
    public func removingExtentOffset() -> CIImage {
        base.transformed(by: .init(translationX: -base.extent.origin.x, y: -base.extent.origin.y))
    }
    
    public func toCVPixelBuffer() -> CVPixelBuffer? {
        // see https://stackoverflow.com/questions/54354138/how-can-you-make-a-cvpixelbuffer-directly-from-a-ciimage-instead-of-a-uiimage-in
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let width  = Int(base.extent.width)
        let height = Int(base.extent.height)
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            return nil
        }
        return pixelBuffer
    }
    
    /// CIImage to cgImage
    /// - Parameters:
    ///   - colorSpace: Color space
    ///   - context: An evaluation context for rendering image processing results and performing image analysis.
    /// - Returns: Newly created CGImage.
    public func toCGImage(colorSpace: CGColorSpace? = nil, context: CIContext? = nil) -> CGImage? {
        if let cgImage = base.cgImage {
            // Returns a CGImageRef if the CIImage was created.
            return cgImage
        }
        let colorSpace = colorSpace ?? Device.colorSpace()
        let context = context ?? Device.context(colorSpace: colorSpace)
        // Pixel format and color space set as discussed around 21:50 in:
        // The `deferred: false` argument is important, to ensure significant rendering work will not
        // be performed later _at drawing time_ on the main thread.
        // See: https://developer.apple.com/videos/play/wwdc2016/505/
        return context.createCGImage(base, from: base.extent, format: CIFormat.RGBAh, colorSpace: colorSpace, deferred: false)
    }
    
    public var hasIOSurface: Bool {
        base.debugDescription.contains("IOSurface")
    }
}

extension CoreImageProtocol {
    
    func outputCIImage(with texture: MTLTexture, name: String) throws -> CIImage {
        guard let ciFilter = (self as? CIImageDisplaying)?.ciFilter ?? {
            CIFilter.init(name: name)
        }() else {
            throw HarbethError.createCIFilter(name)
        }
        guard let cgImage = texture.c7.toCGImage() else {
            throw HarbethError.texture2CGImage
        }
        // Fixed coreImage filter has blank or center flip bug.
        let inputCIImage = CIImage.init(cgImage: cgImage)
        // Series connection other filters and finally output to the main filter.
        let middleImage = try self.coreImageApply(filter: ciFilter, input: inputCIImage)
        ciFilter.setValue(middleImage, forKeyPath: kCIInputImageKey)
        guard let outputImage = ciFilter.outputImage else {
            throw HarbethError.outputCIImage(name)
        }
        if self.croppedOutputImage {
            // Return a new image cropped to a rectangle.
            return outputImage.cropped(to: inputCIImage.extent)
        }
        return outputImage
    }
}

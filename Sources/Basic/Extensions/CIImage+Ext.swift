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
    
    /// Fixed image horizontal flip problem.
    public func fixHorizontalFlip() -> CIImage {
        return base.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
            .transformed(by: CGAffineTransform(translationX: 0, y: base.extent.height))
    }
    
    /// Write CIImage to metal texture synchronously.
    /// Render bounds of CIImage to a Metal texture, optionally specifying what command buffer to use.
    /// - Parameters:
    ///   - texture: Output the texture and write CIImage to the metal texture.
    ///   - commandBuffer: A valid MTLCommandBuffer to receive the encoded filter.
    public func renderCIImageToTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer? = nil) throws {
        guard let commandBuffer = commandBuffer ?? Device.commandQueue().makeCommandBuffer() else {
            throw CustomError.commandBuffer
        }
        let colorSpace = Device.colorSpace()
        let ctx = Device.context(colorSpace: colorSpace)
        let fixedImage = base.c7.fixHorizontalFlip()
        if #available(iOS 11.0, macOS 10.13, *) {
            let renderDestination = CIRenderDestination(mtlTexture: texture, commandBuffer: commandBuffer)
            //try ctx.prepareRender(fixedImage, from: fixedImage.extent, to: renderDestination, at: .zero)
            _ = try ctx.startTask(toRender: fixedImage, to: renderDestination)
        } else {
            ctx.render(fixedImage, to: texture, commandBuffer: commandBuffer, bounds: fixedImage.extent, colorSpace: colorSpace)
        }
        commandBuffer.commitAndWaitUntilCompleted()
    }
    
    /// Asynchronous write CIImage to metal texture.
    /// Render `bounds` of `image` to a Metal texture, optionally specifying what command buffer to use.
    /// - Parameters:
    ///   - texture: Texture type must be MTLTexture2D.
    ///   - commandBuffer: A valid MTLCommandBuffer to receive the encoded filter.
    public func asyncRenderCIImageToTexture(_ texture: MTLTexture,
                                            commandBuffer: MTLCommandBuffer? = nil,
                                            complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
        guard let buffer = commandBuffer ?? Device.commandQueue().makeCommandBuffer() else {
            complete(.failure(CustomError.commandBuffer))
            return
        }
        let colorSpace = Device.colorSpace()
        let ctx = Device.context(colorSpace: colorSpace)
        let fixedImage = fixHorizontalFlip()
        ctx.render(fixedImage, to: texture, commandBuffer: buffer, bounds: fixedImage.extent, colorSpace: colorSpace)
        buffer.asyncCommit(texture: texture, complete: complete)
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

extension C7FilterProtocol {
    
    func outputCIImage(with texture: MTLTexture, name: String) throws -> CIImage {
        guard let ciFiter = CIFilter.init(name: name) else {
            throw CustomError.createCIFilter(name)
        }
        guard let cgImage = texture.c7.toCGImage() else {
            throw CustomError.texture2CGImage
        }
        let inputCIImage = CIImage.init(cgImage: cgImage)
        let ciImage = try (self as! CoreImageProtocol).coreImageApply(filter: ciFiter, input: inputCIImage)
        ciFiter.setValue(ciImage, forKeyPath: kCIInputImageKey)
        guard let outputImage = ciFiter.outputImage else {
            throw CustomError.outputCIImage(name)
        }
        // Return a new image cropped to a rectangle.
        return outputImage.cropped(to: inputCIImage.extent)
    }
}

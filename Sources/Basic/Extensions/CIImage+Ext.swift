//
//  CIImage+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/10/11.
//

import Foundation
import MetalKit

extension CIImage: C7Compatible { }

extension Queen where Base: CIImage {
    
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
    /// Render `bounds` of `image` to a Metal texture, optionally specifying what command buffer to use.
    /// - Parameters:
    ///   - texture: Texture type must be MTLTexture2D.
    ///   - commandBuffer: A valid MTLCommandBuffer to receive the encoded filter.
    public func renderCIImageToTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer? = nil) throws -> MTLTexture {
        guard let buffer = commandBuffer ?? Device.commandQueue().makeCommandBuffer() else {
            throw CustomError.commandBuffer
        }
        let colorSpace = Device.colorSpace()
        let ctx = Device.context(colorSpace: colorSpace)
        // Fixed image horizontal flip problem.
        let fixedImage = fixHorizontalFlip()
        //let origin = CGPoint(x: -scaledImage.extent.origin.x, y: -scaledImage.extent.origin.y)
        //let bounds = CGRect(origin: origin, size: scaledImage.extent.size)
        ctx.render(fixedImage, to: texture, commandBuffer: buffer, bounds: fixedImage.extent, colorSpace: colorSpace)
        // 这俩必须写在`render`同一个方法下面，否则会卡死<很奇怪，没读懂什么意思>
        buffer.commitAndWaitUntilCompleted()
        return texture
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
    ///   - mirrored: New image representing the original image transformeded.
    /// - Returns: Newly created CGImage.
    public func toCGImage(colorSpace: CGColorSpace? = nil, context: CIContext? = nil, mirrored: Bool = false) -> CGImage? {
        if let cgImage = base.cgImage { return cgImage }
        let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let context = context ?? Device.context(colorSpace: colorSpace)
        var ciImage: CIImage = base
        if mirrored, #available(iOS 11.0, macOS 10.13, *) {
            ciImage = ciImage.oriented(.downMirrored)
        }
        return context.createCGImage(ciImage, from: base.extent)
    }
    
    public var hasIOSurface: Bool {
        base.debugDescription.contains("IOSurface")
    }
}

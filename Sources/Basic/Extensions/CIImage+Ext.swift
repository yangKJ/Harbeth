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
    
    /// Write CIImage to metal texture synchronously.
    /// - Parameters:
    ///   - texture: Texture type must be MTLTexture2D.
    ///   - colorSpace: Color space
    ///   - context: An evaluation context for rendering image processing results and performing image analysis.
    public func renderImageToTexture(_ texture: MTLTexture, colorSpace: CGColorSpace? = nil, context: CIContext? = nil) throws {
        guard let buffer = Device.commandQueue().makeCommandBuffer() else {
            throw CustomError.commandBuffer
        }
        let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let ctx = context ?? Device.context(colorSpace: colorSpace)
        // Fixed image horizontal flip problem.
        let scaledImage = base.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
            .transformed(by: CGAffineTransform(translationX: 0, y: base.extent.height))
        //let origin = CGPoint(x: -scaledImage.extent.origin.x, y: -scaledImage.extent.origin.y)
        //let bounds = CGRect(origin: origin, size: scaledImage.extent.size)
        ctx.render(scaledImage, to: texture, commandBuffer: buffer, bounds: scaledImage.extent, colorSpace: colorSpace)
        // 这俩必须写在`render`同一个方法下面，否则会卡死<很奇怪，没读懂什么意思>
        buffer.commit()
        buffer.waitUntilCompleted()
    }
    
    /// Asynchronous write CIImage to metal texture.
    /// Render `bounds` of `image` to a Metal texture, optionally specifying what command buffer to use.
    /// - Parameters:
    ///   - texture: Texture type must be MTLTexture2D.
    ///   - colorSpace: Color space
    ///   - context: An evaluation context for rendering image processing results and performing image analysis.
    public func writeCIImageAtTexture(_ texture: MTLTexture,
                                      complete: @escaping (Result<MTLTexture, CustomError>) -> Void,
                                      colorSpace: CGColorSpace? = nil,
                                      context: CIContext? = nil) {
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            complete(.failure(CustomError.commandBuffer))
            return
        }
        let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let ctx = context ?? Device.context(colorSpace: colorSpace)
        let scaledImage = base.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
            .transformed(by: CGAffineTransform(translationX: 0, y: base.extent.height))
        ctx.render(scaledImage, to: texture, commandBuffer: commandBuffer, bounds: scaledImage.extent, colorSpace: colorSpace)
        commandBuffer.addCompletedHandler { (buffer) in
            switch buffer.status {
            case .completed:
                complete(.success(texture))
            case .error where buffer.error != nil:
                complete(.failure(.error(buffer.error!)))
            default:
                break
            }
        }
        commandBuffer.commit()
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

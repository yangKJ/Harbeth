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
    
    /// Renders a region of an image to a Metal texture.
    /// Render `bounds` of `image` to a Metal texture, optionally specifying what command buffer to use.
    /// - Parameters:
    ///   - texture: Texture type must be MTLTexture2D.
    ///   - colorSpace: Color space
    ///   - context: An evaluation context for rendering image processing results and performing image analysis.
    public func renderImageToTexture(_ texture: MTLTexture, colorSpace: CGColorSpace? = nil, context: CIContext? = nil) {
        let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let ctx = context ?? Device.context(colorSpace: colorSpace)
        let buffer = Device.commandQueue().makeCommandBuffer()
        // Fixed image horizontal flip problem.
        let scaledImage = base.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
            .transformed(by: CGAffineTransform(translationX: 0, y: base.extent.height))
        //let origin = CGPoint(x: -scaledImage.extent.origin.x, y: -scaledImage.extent.origin.y)
        //let bounds = CGRect(origin: origin, size: scaledImage.extent.size)
        ctx.render(scaledImage, to: texture, commandBuffer: buffer, bounds: scaledImage.extent, colorSpace: colorSpace)
        buffer?.commit()
        buffer?.waitUntilCompleted()
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
        if let cgImage = base.cgImage { return cgImage }
        let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let context = context ?? Device.context(colorSpace: colorSpace)
        return context.createCGImage(base, from: base.extent)
    }
}

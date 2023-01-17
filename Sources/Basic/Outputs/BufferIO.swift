//
//  BufferIO.swift
//  Harbeth
//
//  Created by Condy on 2023/1/15.
//

import Foundation
import MetalKit

public struct BufferIO {
    /// CVPixelBuffer add filters and converts into C7Image.
    /// - Parameters:
    ///   - pixelBuffer: Based on the image buffer type. The pixel buffer implements the memory storage for an image buffer.
    ///   - filters: It must be an array object implementing C7FilterProtocol.
    ///   - bufferPixelFormat: Since the camera acquisition generally uses `kCVPixelFormatType_32BGRA`, so use `bgra8Unorm`
    ///   - textureCache: The texture cache object that will manage the texture. Only the real machine used.
    /// - Returns: ``CVPixelBuffer => C7Image``
    @inlinable public static func convert2Image(pixelBuffer: CVPixelBuffer?,
                                                filters: [C7FilterProtocol],
                                                bufferPixelFormat: MTLPixelFormat = .bgra8Unorm,
                                                textureCache: CVMetalTextureCache? = nil) -> C7Image? {
        if filters.isEmpty {
            // Fixed rgba => bgra when no filter.
            return pixelBuffer?.mt.toCGImage()?.mt.toC7Image()
        } else {
            let texture = convert2MTLTexture(pixelBuffer: pixelBuffer,
                                             filters: filters,
                                             bufferPixelFormat: bufferPixelFormat,
                                             textureCache: textureCache)
            return texture?.toImage()
        }
    }
    
    /// CVPixelBuffer add filters and converts into MTLTexture.
    /// - Parameters:
    ///   - pixelBuffer: Based on the image buffer type. The pixel buffer implements the memory storage for an image buffer.
    ///   - filters: It must be an array object implementing C7FilterProtocol.
    ///   - bufferPixelFormat: Since the camera acquisition generally uses `kCVPixelFormatType_32BGRA`, so use `bgra8Unorm`
    ///   - textureCache: The texture cache object that will manage the texture. Only the real machine used.
    /// - Returns: ``CVPixelBuffer => MTLTexture``
    public static func convert2MTLTexture(pixelBuffer: CVPixelBuffer?,
                                          filters: [C7FilterProtocol],
                                          bufferPixelFormat: MTLPixelFormat = .bgra8Unorm,
                                          textureCache: CVMetalTextureCache? = nil) -> MTLTexture? {
        if filters.isEmpty {
            // Fixed rgba => bgra when no filter.
            // pixelBuffer.mt.toCGImage()?.mt.toTexture(pixelFormat: bufferPixelFormat)
            return pixelBuffer?.mt.createMTLTexture(pixelFormat: bufferPixelFormat)
        }
        guard var texture = pixelBuffer?.mt.toMTLTexture(textureCache: textureCache) else {
            return nil
        }
        for filter in filters {
            let OSize = filter.resize(input: C7Size(width: texture.width, height: texture.height))
            // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
            // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
            let OTexture = Processed.destTexture(pixelFormat: bufferPixelFormat, width: OSize.width, height: OSize.height)
            texture = (try? Processed.IO(inTexture: texture, outTexture: OTexture, filter: filter)) ?? texture
        }
        return texture
    }
}

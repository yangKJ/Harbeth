//
//  BoxxIO.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//

import Foundation
import MetalKit
import CoreImage
import CoreMedia
import CoreVideo

/// Support ` UIImage, CGImage, CIImage, MTLTexture, CMSampleBuffer, CVPixelBuffer `
@frozen public struct BoxxIO<Dest> : Destype {
    public typealias Element = Dest
    public var element: Dest
    public var filters: [C7FilterProtocol]
    
    // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
    // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
    public var bufferPixelFormat: MTLPixelFormat = .bgra8Unorm
    
    // When the CIImage is created, it is mirrored and flipped upside down.
    // But upon inspecting the texture, it still renders the CIImage as expected.
    // Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
    public var mirrored: Bool = false
    
    #if os(macOS)
    // Fixed an issue with HEIC flipping after adding filter.
    // If drawing a HEIC, we need to make context flipped.
    public var heic: Bool = false
    #endif
    
    public init(element: Dest, filter: C7FilterProtocol) {
        self.init(element: element, filters: [filter])
    }
    
    public init(element: Dest, filters: [C7FilterProtocol]) {
        self.element = element
        self.filters = filters
    }
    
    public func output() throws -> Dest {
        do {
            if let element = element as? C7Image {
                return try filtering(image: element) as! Dest
            }
            if let element = element as? MTLTexture {
                return try filtering(texture: element) as! Dest
            }
            if CFGetTypeID(element as CFTypeRef) == CGImage.typeID {
                return try filtering(cgImage: element as! CGImage) as! Dest
            }
            if let element = element as? CIImage {
                return try filtering(ciImage: element) as! Dest
            }
            if CFGetTypeID(element as CFTypeRef) == CVPixelBufferGetTypeID() {
                return try filtering(pixelBuffer: element as! CVPixelBuffer) as! Dest
            }
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *),
               CFGetTypeID(element as CFTypeRef) == CMSampleBuffer.typeID {
                return try filtering(sampleBuffer: element as! CMSampleBuffer) as! Dest
            }
        } catch {
            throw error
        }
        return element
    }
}

extension BoxxIO {
    
    /// CVPixelBuffer add filters and converts into C7Image.
    /// - Parameters:
    ///   - pixelBuffer: Based on the image buffer type. The pixel buffer implements the memory storage for an image buffer.
    ///   - filters: It must be an array object implementing C7FilterProtocol.
    ///   - bufferPixelFormat: Since the camera acquisition generally uses `kCVPixelFormatType_32BGRA`, so use `bgra8Unorm`
    /// - Returns: ``CVPixelBuffer => C7Image``
    public static func convert2Image(pixelBuffer: CVPixelBuffer?,
                                     filters: [C7FilterProtocol],
                                     bufferPixelFormat: MTLPixelFormat = .bgra8Unorm) -> C7Image? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        if filters.isEmpty {
            // Fixed rgba => bgra when no filter is introduced.
            guard let cgimage = pixelBuffer.mt.toCGImage() else { return nil }
            return cgimage.mt.toC7Image()
        }
        guard var texture = pixelBuffer.mt.convert2MTLTexture(textureCache: Device.sharedTextureCache()) else {
            return nil
        }
        for filter in filters {
            let OSize = filter.resize(input: C7Size(width: texture.width, height: texture.height))
            // Since the camera acquisition generally uses ' kCVPixelFormatType_32BGRA '
            // The pixel format needs to be consistent, otherwise it will appear blue phenomenon.
            let OTexture = Processed.destTexture(pixelFormat: bufferPixelFormat, width: OSize.width, height: OSize.height)
            texture = (try? Processed.IO(inTexture: texture, outTexture: OTexture, filter: filter)) ?? texture
        }
        return texture.toImage()
    }
}

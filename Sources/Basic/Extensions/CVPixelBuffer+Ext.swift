//
//  CVPixelBuffer+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/2/28.
//

import Foundation
import CoreVideo
import MetalKit
import VideoToolbox

extension CVPixelBuffer: HarbethCompatible { }

extension HarbethWrapper where Base: CVPixelBuffer {
    
    /// Width of the pixel buffer
    public var width: Int {
        CVPixelBufferGetWidth(base)
    }
    
    /// Height of the pixel buffer
    public var height: Int {
        CVPixelBufferGetHeight(base)
    }
    
    /// Calculated size based on plane 0
    private var size: C7Size {
        let width = CVPixelBufferGetWidthOfPlane(self.base, 0)
        let height = CVPixelBufferGetHeightOfPlane(self.base, 0)
        return C7Size(width: width, height: height)
    }
    
    /// Converts pixel buffer to Metal texture
    /// - Parameters:
    ///   - textureCache: The texture cache object that will manage the texture.
    ///   - pixelFormat: Specifies the Metal pixel format.
    ///   - planeIndex: Specifies the plane of the CVImageBuffer to map bind.  Ignored for non-planar CVImageBuffers.
    /// - Returns: Metal texture.
    public func convert2MTLTexture(textureCache: CVMetalTextureCache?,
                                   pixelFormat: MTLPixelFormat = .bgra8Unorm,
                                   planeIndex: Int = 0) -> MTLTexture? {
        guard let textureCache = textureCache else {
            return nil
        }
        #if !targetEnvironment(simulator)
        var cvmTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  textureCache,
                                                  self.base,
                                                  nil,
                                                  pixelFormat,
                                                  CVPixelBufferGetWidthOfPlane(base, planeIndex),
                                                  CVPixelBufferGetHeightOfPlane(base, planeIndex),
                                                  planeIndex,
                                                  &cvmTexture)
        if let cvmTexture = cvmTexture, let texture = CVMetalTextureGetTexture(cvmTexture) {
            return texture
        }
        #endif
        return nil
    }
    
    /// Creates CGImage from pixel buffer
    /// - Returns: CGImage or nil
    public func toCGImage() -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(base, options: nil, imageOut: &cgImage)
        return cgImage
    }
    
    /// Creates CIImage from pixel buffer
    /// - Returns: CIImage or nil
    public func toCIImage() -> CIImage? {
        CIImage(cvPixelBuffer: base)
    }
    
    /// Copies texture data to pixel buffer
    /// - Parameter texture: Source Metal texture
    @discardableResult
    public func copyToPixelBuffer(with texture: MTLTexture) -> Bool {
        lockBaseAddress(.readOnly)
        defer { unlockBaseAddress(.readOnly) }
        
        guard let pixelBufferBytes = CVPixelBufferGetBaseAddress(base) else {
            return false
        }
        // Fixed if the CVPixelBuffer and MTLTexture size is not equal.
        // If the size is inconsistent, using the modified size filter will crash.
        // Such as: C7Resize, C7Crop and so on Shape filter.
        guard base.c7.size == texture.c7.toC7Size() else {
            return false
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(base)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(pixelBufferBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        return true
    }
    
    /// Creates new pixel buffer from texture
    /// - Parameter texture: Source Metal texture
    /// - Returns: New pixel buffer
    public func copyToCVPixelBuffer(with texture: MTLTexture) -> CVPixelBuffer {
        lockBaseAddress(.readOnly)
        defer { unlockBaseAddress(.readOnly) }
        var outPixelbuffer: CVPixelBuffer? = base
        if let datas = texture.buffer?.contents() {
            CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                         texture.width,
                                         texture.height,
                                         kCVPixelFormatType_64RGBAHalf,
                                         datas,
                                         texture.bufferBytesPerRow,
                                         nil, nil, nil,
                                         &outPixelbuffer);
        }
        return outPixelbuffer ?? base
    }
    
    /// Creates CMSampleBuffer from pixel buffer
    /// - Returns: CMSampleBuffer or nil
    public func toCMSampleBuffer() -> CMSampleBuffer? {
        var newSampleBuffer: CMSampleBuffer?
        var timimgInfo = CMSampleTimingInfo.invalid
        var videoInfo: CMVideoFormatDescription?
        
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: base, formatDescriptionOut: &videoInfo)
        guard let videoInfo = videoInfo else {
            return nil
        }
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                           imageBuffer: base,
                                           dataReady: true,
                                           makeDataReadyCallback: nil,
                                           refcon: nil,
                                           formatDescription: videoInfo,
                                           sampleTiming: &timimgInfo,
                                           sampleBufferOut: &newSampleBuffer)
        return newSampleBuffer
    }
    
    /// Converts to Metal texture based on environment
    /// - Parameter textureCache: Texture cache (real device only)
    /// - Returns: Metal texture or nil
    public func toMTLTexture(textureCache: CVMetalTextureCache? = nil) -> MTLTexture? {
        #if targetEnvironment(simulator)
        // Simulator requires rgba8Unorm format
        let pixelFormat: MTLPixelFormat = .rgba8Unorm
        return base.c7.toCGImage()?.c7.toTexture(pixelFormat: pixelFormat)
        #else
        let cache = textureCache ?? Device.sharedTextureCache()
        return base.c7.convert2MTLTexture(textureCache: cache)
        #endif
    }
    
    /// Creates new Metal texture from pixel buffer
    /// - Parameters:
    ///   - pixelFormat: Metal pixel format
    ///   - planeIndex: Plane index for planar buffers
    /// - Returns: New Metal texture
    /// - Throws: Texture creation error
    public func createMTLTexture(pixelFormat: MTLPixelFormat = .bgra8Unorm, planeIndex: Int = 0) throws -> MTLTexture {
        let width = CVPixelBufferGetWidthOfPlane(self.base, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(self.base, planeIndex)
        let texture = try TextureLoader.makeTexture(width: width, height: height, options: [
            .texturePixelFormat: pixelFormat
        ])
        
        let success = base.c7.copyToPixelBuffer(with: texture)
        if !success {
            throw NSError(domain: "Harbeth", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to copy pixel buffer"])
        }
        
        return texture
    }
    
    /// Locks pixel buffer memory for access
    /// - Parameter lockFlags: Lock flags
    /// - Returns: Lock status
    @discardableResult
    public func lockBaseAddress(_ lockFlags: CVPixelBufferLockFlags = .readOnly) -> CVReturn {
        return CVPixelBufferLockBaseAddress(base, lockFlags)
    }
    
    /// Unlocks pixel buffer memory
    /// - Parameter lockFlags: Lock flags
    /// - Returns: Unlock status
    @discardableResult
    public func unlockBaseAddress(_ lockFlags: CVPixelBufferLockFlags = .readOnly) -> CVReturn {
        return CVPixelBufferUnlockBaseAddress(base, lockFlags)
    }
}

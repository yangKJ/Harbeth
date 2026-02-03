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
import CoreMedia

private final class HarbethSimulatorCache {
    static let shared = HarbethSimulatorCache()
    private let cache = NSMapTable<CVPixelBuffer, MTLTexture>.weakToStrongObjects()
    
    func texture(for pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        return cache.object(forKey: pixelBuffer)
    }
    
    func cache(_ texture: MTLTexture, for pixelBuffer: CVPixelBuffer) {
        cache.setObject(texture, forKey: pixelBuffer)
    }
}

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
        let w = CVPixelBufferGetWidthOfPlane(base, 0)
        let h = CVPixelBufferGetHeightOfPlane(base, 0)
        return C7Size(width: w, height: h)
    }
    
    private func inferMetalPixelFormat(for planeIndex: Int = 0) -> MTLPixelFormat? {
        if CVPixelBufferIsPlanar(base) {
            return planeIndex == 0 ? .r8Unorm : .rg8Unorm
        }
        switch CVPixelBufferGetPixelFormatType(base) {
        case kCVPixelFormatType_32BGRA:
            return .bgra8Unorm
        case kCVPixelFormatType_32RGBA:
            return .rgba8Unorm
        case kCVPixelFormatType_32ARGB:
            return .bgra8Unorm // Metal doesn't have ARGB, BGRA is equivalent with swizzle
        case kCVPixelFormatType_64RGBAHalf:
            return .rgba16Float
        default:
            return nil
        }
    }
    
    /// Converts pixel buffer to Metal texture
    /// - Parameters:
    ///   - textureCache: The texture cache object that will manage the texture.
    ///   - pixelFormat: Specifies the Metal pixel format.
    ///   - planeIndex: Specifies the plane of the CVImageBuffer to map bind.  Ignored for non-planar CVImageBuffers.
    /// - Returns: Metal texture.
    public func convert2MTLTexture(textureCache: CVMetalTextureCache?,
                                   pixelFormat: MTLPixelFormat? = nil,
                                   planeIndex: Int = 0) -> MTLTexture? {
        guard let textureCache = textureCache else { return nil }
        #if targetEnvironment(simulator)
        return nil
        #else
        let planeCount = CVPixelBufferGetPlaneCount(base)
        if planeIndex >= planeCount {
            return nil
        }
        
        let lockStatus = CVPixelBufferLockBaseAddress(base, .readOnly)
        guard lockStatus == kCVReturnSuccess else {
            print("⚠️ [Harbeth] Failed to lock pixel buffer for Metal texture creation")
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(base, .readOnly) }
        let width = CVPixelBufferGetWidthOfPlane(base, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(base, planeIndex)
        let format = pixelFormat ?? inferMetalPixelFormat(for: planeIndex) ?? .bgra8Unorm
        var cvmTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               textureCache, base,
                                                               nil,
                                                               format, width, height,
                                                               planeIndex, &cvmTexture)
        guard status == kCVReturnSuccess, let cvmTexture = cvmTexture else {
            return nil
        }
        return CVMetalTextureGetTexture(cvmTexture)
        #endif
    }
    
    /// Creates CGImage from pixel buffer
    /// - Returns: CGImage or nil
    public func toCGImage() -> CGImage? {
        guard CVPixelBufferLockBaseAddress(base, .readOnly) == kCVReturnSuccess else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(base, .readOnly) }
        var cgImage: CGImage?
        let result = VTCreateCGImageFromCVPixelBuffer(base, options: nil, imageOut: &cgImage)
        return (result == noErr) ? cgImage : nil
    }
    
    public func toCIImage() -> CIImage? {
        // CIImage holds a reference; no need to lock here
        return CIImage(cvImageBuffer: base, options: [:])
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
    
    /// Copies data FROM this pixel buffer TO the given Metal texture.
    public func copyDataTo(texture: MTLTexture, planeIndex: Int = 0) -> Bool {
        guard texture.usage.contains(.shaderWrite) else {
            return false
        }
        let w = texture.width, h = texture.height
        guard w == CVPixelBufferGetWidthOfPlane(base, planeIndex) && h == CVPixelBufferGetHeightOfPlane(base, planeIndex) else {
            return false
        }
        let lockStatus = CVPixelBufferLockBaseAddress(base, .readOnly)
        guard lockStatus == kCVReturnSuccess else { return false }
        defer { CVPixelBufferUnlockBaseAddress(base, .readOnly) }
        guard let srcBytes = CVPixelBufferGetBaseAddressOfPlane(base, planeIndex) else {
            return false
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(base, planeIndex)
        let region = MTLRegionMake2D(0, 0, w, h)
        texture.replace(region: region, mipmapLevel: 0, withBytes: srcBytes, bytesPerRow: bytesPerRow)
        return true
    }
    
    /// Copies data FROM the given Metal texture TO this pixel buffer.
    public func copyDataFrom(texture: MTLTexture) -> Bool {
        guard texture.usage.contains(.shaderRead) else {
            return false
        }
        let w = texture.width, h = texture.height
        guard w == CVPixelBufferGetWidth(base) && h == CVPixelBufferGetHeight(base) else {
            return false
        }
        let lockStatus = CVPixelBufferLockBaseAddress(base, [])
        guard lockStatus == kCVReturnSuccess else { return false }
        defer { CVPixelBufferUnlockBaseAddress(base, []) }
        guard let dstBytes = CVPixelBufferGetBaseAddress(base) else {
            return false
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(base)
        let region = MTLRegionMake2D(0, 0, w, h)
        texture.getBytes(dstBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        return true
    }
    
    /// Creates new pixel buffer from texture
    /// - Parameter texture: Source Metal texture
    /// - Returns: New pixel buffer
    public func createCVPixelBuffer(from texture: MTLTexture, pixelFormat: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer? {
        var newPB: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil,
                                         texture.width,
                                         texture.height,
                                         pixelFormat,
                                         [:] as CFDictionary,
                                         &newPB)
        guard status == kCVReturnSuccess, let pb = newPB else {
            return nil
        }
        return pb.c7.copyDataFrom(texture: texture) ? pb : nil
    }
    
    /// Creates new Metal texture from pixel buffer
    /// - Parameters:
    ///   - pixelFormat: Metal pixel format
    ///   - planeIndex: Plane index for planar buffers
    /// - Returns: New Metal texture
    /// - Throws: Texture creation error
    public func createMTLTexture(pixelFormat: MTLPixelFormat? = nil, planeIndex: Int = 0) throws -> MTLTexture {
        let width = CVPixelBufferGetWidthOfPlane(base, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(base, planeIndex)
        let format = pixelFormat ?? inferMetalPixelFormat(for: planeIndex) ?? .bgra8Unorm
        let texture = try TextureLoader.makeTexture(width: width, height: height, options: [
            .texturePixelFormat: format,
            .textureUsage: [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]
        ])
        if !copyDataTo(texture: texture, planeIndex: planeIndex) {
            throw HarbethError.textureCreateFailed
        }
        return texture
    }
    
    public func toCMSampleBuffer(timing: CMSampleTimingInfo? = nil) -> CMSampleBuffer? {
        var timingInfo = timing ?? CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: .invalid,
            decodeTimeStamp: .invalid
        )
        var formatDesc: CMVideoFormatDescription?
        let fdStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: nil,
            imageBuffer: base,
            formatDescriptionOut: &formatDesc
        )
        guard fdStatus == noErr, let formatDesc = formatDesc else {
            return nil
        }
        var sampleBuffer: CMSampleBuffer?
        let sbStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: base,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        return (sbStatus == noErr) ? sampleBuffer : nil
    }
    
    public func toMTLTexture(textureCache: CVMetalTextureCache? = nil) -> MTLTexture? {
        #if targetEnvironment(simulator)
        // Use cached conversion to avoid repeated CG decode
        if let cached = HarbethSimulatorCache.shared.texture(for: base) {
            return cached
        }
        guard let cgImage = base.c7.toCGImage() else { return nil }
        let pixelFormat: MTLPixelFormat = inferMetalPixelFormat() ?? .rgba8Unorm
        guard let texture = cgImage.c7.toTexture(pixelFormat: pixelFormat) else { return nil }
        HarbethSimulatorCache.shared.cache(texture, for: base)
        return texture
        #else
        let cache = textureCache ?? Device.sharedTextureCache()
        return base.c7.convert2MTLTexture(textureCache: cache)
        #endif
    }
    
    @discardableResult
    public func lockBaseAddress(_ flags: CVPixelBufferLockFlags = .readOnly) -> CVReturn {
        CVPixelBufferLockBaseAddress(base, flags)
    }
    
    @discardableResult
    public func unlockBaseAddress(_ flags: CVPixelBufferLockFlags = .readOnly) -> CVReturn {
        CVPixelBufferUnlockBaseAddress(base, flags)
    }
}

//
//  MTLTexture+Ext.swift
//  Harbeth
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import MetalKit
import ImageIO
import Accelerate
import CoreImage

extension MTLTexture {
    /// Add the `c7` prefix namespace
    public var c7: MTLTextureCompatible_ {
        MTLTextureCompatible_(target: self)
    }
}

public struct MTLTextureCompatible_ {
    
    let target: MTLTexture
    
    init(target: MTLTexture) {
        self.target = target
    }
    
    public var size: MTLSize {
        .init(width: target.width, height: target.height, depth: target.depth)
    }
    
    public var region: MTLRegion {
        .init(origin: MTLOrigin(x: 0, y: 0, z: 0), size: size)
    }
    
    public var descriptor: MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = target.width
        descriptor.height = target.height
        descriptor.depth = target.depth
        descriptor.arrayLength = target.arrayLength
        descriptor.storageMode = target.storageMode
        descriptor.cpuCacheMode = target.cpuCacheMode
        descriptor.usage = target.usage
        descriptor.textureType = target.textureType
        descriptor.sampleCount = target.sampleCount
        descriptor.mipmapLevelCount = target.mipmapLevelCount
        descriptor.pixelFormat = target.pixelFormat
        if #available(iOS 12.0, macOS 10.14, *) {
            descriptor.allowGPUOptimizedContents = target.allowGPUOptimizedContents
        }
        return descriptor
    }
    
    /// Checks if the texture is fully transparent (alpha = 0 for all pixels).
    /// Only supports `.bgra8Unorm`, `.rgba8Unorm`, and grayscale formats.
    /// Returns `false` for unsupported formats (conservative assumption: not blank).
    public func isBlank() -> Bool {
        let format = target.pixelFormat
        if format == .a8Unorm || format == .r8Unorm {
            let width = target.width
            let height = target.height
            let rowBytes = width
            let totalBytes = rowBytes * height
            let data = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
            defer { data.deallocate() }
            let region = MTLRegionMake2D(0, 0, width, height)
            target.getBytes(data, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
            return data.withMemoryRebound(to: UInt8.self, capacity: totalBytes) {
                for i in 0..<totalBytes {
                    if $0[i] != 0 { return false }
                }
                return true
            }
        }
        
        // Handle RGBA/BGRA
        guard format == .bgra8Unorm || format == .bgra8Unorm_srgb ||
              format == .rgba8Unorm || format == .rgba8Unorm_srgb else {
            return false // unsupported → assume non-blank
        }
        
        let width = target.width
        let height = target.height
        let rowBytes = width * 4
        let totalBytes = rowBytes * height
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
        defer { data.deallocate() }
        let region = MTLRegionMake2D(0, 0, width, height)
        target.getBytes(data, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
        // Alpha is always at index 3 for both BGRA and RGBA
        for i in stride(from: 3, to: totalBytes, by: 4) {
            if data[i] != 0 {
                return false
            }
        }
        return true
    }
    
    public func toC7Size() -> C7Size {
        C7Size(width: target.width, height: target.height)
    }
    
    public func toImage() -> C7Image? {
        guard let cgImage = toCGImage() else {
            return nil
        }
        return cgImage.c7.toC7Image()
    }
    
    /// Converts to CIImage with best-effort zero-copy strategy.
    public func toCIImage() -> CIImage? {
        if let cgImage = toCGImage() {
            return CIImage(cgImage: cgImage)
        }
        return CIImage(mtlTexture: target, options: nil)
    }
    
    public func toCIImage(mirrored: Bool) throws -> CIImage {
        guard let ciImage = toCIImage() else {
            throw HarbethError.texture2CIImage
        }
        if mirrored, #available(iOS 11.0, macOS 10.13, *) {
            // When the CIImage is created, it is mirrored and flipped upside down.
            // But upon inspecting the texture, it still renders the CIImage as expected.
            // Nevertheless, we can fix this by simply transforming the CIImage with the downMirrored orientation.
            return ciImage.oriented(.downMirrored)
        }
        return ciImage
    }
    
    public func fixImageOrientation(refImage: C7Image) throws -> C7Image {
        guard let cgImage = toCGImage() else {
            throw HarbethError.texture2Image
        }
        return cgImage.c7.drawing(refImage: refImage).c7.flattened()
    }
    
    /// Create a CGImage with the data and information we provided.
    /// Each pixel contains of 4 UInt8s or 32 bits, each byte is representing one channel.
    /// The layout of the pixels is described with bitmap info.
    /// Process steps：``Data => CFData => CGDataProvider => CGImage``
    /// - Parameters:
    ///   - colorSpace: Color space
    ///   - pixelFormat: Current Metal texture pixel format.
    /// - Returns: CGImage
    public func toCGImage(colorSpace: CGColorSpace? = nil, pixelFormat: MTLPixelFormat? = nil) -> CGImage? {
        let width  = target.width
        let height = target.height
        let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
        switch pixelFormat ?? self.target.pixelFormat {
        case .a8Unorm, .r8Unorm, .r8Uint:
            let rowBytes = width
            let length = rowBytes * height
            let rgbaBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
            defer { rgbaBytes.deallocate() }
            target.getBytes(rgbaBytes, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
            
            let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceGray()
            let rawV = pixelFormat == .a8Unorm ? CGImageAlphaInfo.alphaOnly.rawValue : CGImageAlphaInfo.none.rawValue
            let bitmapInfo = CGBitmapInfo(rawValue: rawV)
            guard let data = CFDataCreate(nil, rgbaBytes, length),
                  let dataProvider = CGDataProvider(data: data),
                  let cgImage = CGImage(width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bitsPerPixel: 8,
                                        bytesPerRow: rowBytes,
                                        space: colorSpace,
                                        bitmapInfo: bitmapInfo,
                                        provider: dataProvider,
                                        decode: nil,
                                        shouldInterpolate: true,
                                        intent: .defaultIntent) else {
                return nil
            }
            return cgImage
        case .bgra8Unorm, .bgra8Unorm_srgb:
            // read texture as byte array
            let rowBytes = width * 4
            let length = rowBytes * height
            let bgraBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
            let rgbaBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
            defer { bgraBytes.deallocate(); rgbaBytes.deallocate() }
            target.getBytes(bgraBytes, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
            
            // use Accelerate framework to convert from BGRA to RGBA
            var bgraBuffer = vImage_Buffer(data: bgraBytes,
                                           height: vImagePixelCount(height),
                                           width: vImagePixelCount(width),
                                           rowBytes: rowBytes)
            var rgbaBuffer = vImage_Buffer(data: rgbaBytes,
                                           height: vImagePixelCount(height),
                                           width: vImagePixelCount(width),
                                           rowBytes: rowBytes)
            let map: [UInt8] = [2, 1, 0, 3]
            vImagePermuteChannels_ARGB8888(&bgraBuffer, &rgbaBuffer, map, 0)
            
            // create CGImage with RGBA Flipped Bytes
            let colorSpace = colorSpace ?? Device.colorSpace()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let data = CFDataCreate(nil, rgbaBytes, length),
                  let dataProvider = CGDataProvider(data: data),
                  let cgImage = CGImage(width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bitsPerPixel: 32,
                                        bytesPerRow: rowBytes,
                                        space: colorSpace,
                                        bitmapInfo: bitmapInfo,
                                        provider: dataProvider,
                                        decode: nil,
                                        shouldInterpolate: true,
                                        intent: .defaultIntent) else {
                return nil
            }
            return cgImage
        case .rgba8Unorm, .rgba8Unorm_srgb:
            let rowBytes = width * 4
            let length = rowBytes * height
            let rgbaBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
            defer { rgbaBytes.deallocate() }
            target.getBytes(rgbaBytes, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
            
            let colorSpace = colorSpace ?? Device.colorSpace()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let data = CFDataCreate(nil, rgbaBytes, length),
                  let dataProvider = CGDataProvider(data: data),
                  let cgImage = CGImage(width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bitsPerPixel: 32,
                                        bytesPerRow: rowBytes,
                                        space: colorSpace,
                                        bitmapInfo: bitmapInfo,
                                        provider: dataProvider,
                                        decode: nil,
                                        shouldInterpolate: true,
                                        intent: .defaultIntent) else {
                return nil
            }
            return cgImage
        default:
            return nil
        }
    }
    
    /// Returns raw pixel data as `Data`. Always returns 4-channel RGBA8 for color formats.
    /// ⚠️ This triggers a GPU → CPU transfer. Use sparingly!
    public func bytes() -> Data? {
        guard target.pixelFormat == .bgra8Unorm || target.pixelFormat == .rgba8Unorm else {
            return nil
        }
        let width = target.width
        let height = target.height
        let rowBytes = width * 4
        let totalBytes = rowBytes * height
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
        defer { buffer.deallocate() }
        let region = MTLRegionMake2D(0, 0, width, height)
        target.getBytes(buffer, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
        if target.pixelFormat == .bgra8Unorm {
            // Convert in-place using vImage
            var src = vImage_Buffer(data: buffer, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            var dst = vImage_Buffer(data: buffer, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            let map: [UInt8] = [2, 1, 0, 3]
            vImagePermuteChannels_ARGB8888(&src, &dst, map, vImage_Flags(0))
        }
        return Data(bytes: buffer, count: totalBytes)
    }
}

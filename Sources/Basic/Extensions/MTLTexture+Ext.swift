//
//  Transform.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import MetalKit
import ImageIO
import Accelerate

extension MTLTexture {
    /// Add the `mt` prefix namespace
    public var mt: MTLTextureCompatible_ {
        MTLTextureCompatible_(target: self)
    }
}

public struct MTLTextureCompatible_ {
    
    public let target: MTLTexture
    
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
        if #available(iOS 12, macOS 10.14, *) {
            descriptor.allowGPUOptimizedContents = target.allowGPUOptimizedContents
        }
        return descriptor
    }
    
    public func isBlank() -> Bool {
        let width = target.width
        let height = target.height
        let bytesPerRow = width * 4
        let data = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * height, alignment: 4)
        defer { data.deallocate() }
        let region = MTLRegionMake2D(0, 0, width, height)
        target.getBytes(data, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        var bind = data.assumingMemoryBound(to: UInt8.self)
        var sum: UInt8 = 0
        for _ in 0..<width*height {
            sum += bind.pointee
            bind = bind.advanced(by: 1)
        }
        return sum != 0
    }
    
    public func toC7Size() -> C7Size {
        C7Size(width: target.width, height: target.height)
    }
    
    public func toImage() -> C7Image? {
        guard let cgImage = toCGImage() else {
            return nil
        }
        return cgImage.mt.toC7Image()
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
            
            let colorScape = colorSpace ?? CGColorSpaceCreateDeviceGray()
            let rawV = pixelFormat == .a8Unorm ? CGImageAlphaInfo.alphaOnly.rawValue : CGImageAlphaInfo.none.rawValue
            let bitmapInfo = CGBitmapInfo(rawValue: rawV)
            guard let data = CFDataCreate(nil, rgbaBytes, length),
                  let dataProvider = CGDataProvider(data: data),
                  let cgImage = CGImage(width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bitsPerPixel: 8,
                                        bytesPerRow: rowBytes,
                                        space: colorScape,
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
            let colorScape = colorSpace ?? CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let data = CFDataCreate(nil, rgbaBytes, length),
                  let dataProvider = CGDataProvider(data: data),
                  let cgImage = CGImage(width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bitsPerPixel: 32,
                                        bytesPerRow: rowBytes,
                                        space: colorScape,
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
            
            let colorScape = colorSpace ?? CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let data = CFDataCreate(nil, rgbaBytes, length),
                  let dataProvider = CGDataProvider(data: data),
                  let cgImage = CGImage(width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bitsPerPixel: 32,
                                        bytesPerRow: rowBytes,
                                        space: colorScape,
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
}

extension MTLTextureCompatible_ {
    /// Create a texture for later storage according to the texture parameters.
    /// - Parameters:
    ///   - pixelformat: Indicates the pixelFormat, The format of the picture should be consistent with the data
    ///   - width: The texture width, must be greater than 0.
    ///   - height: The texture height, must be greater than 0.
    ///   - usage: Description of texture usage
    ///   - mipmapped: No mapping was required
    ///   - device: Device information to create other objects.
    /// - Returns: New textures
    public static func destTexture(_ pixelFormat: MTLPixelFormat = MTLPixelFormat.rgba8Unorm,
                                   width: Int, height: Int,
                                   usage: MTLTextureUsage = [.shaderRead, .shaderWrite],
                                   mipmapped: Bool = false,
                                   device: MTLDevice? = nil) -> MTLTexture {
        let width  = max(1, width)
        let height = max(1, height)
        // Create a TextureDescriptor for a common 2D texture.
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: mipmapped)
        descriptor.usage = usage
        #if targetEnvironment(macCatalyst)
        descriptor.storageMode = .managed
        #endif
        let device = device ?? Device.device()
        return device.makeTexture(descriptor: descriptor)!
    }
    
    /// Create a metal texture that only supports rendering.
    /// - Parameters:
    ///   - pixelformat: Indicates the pixelFormat, The format of the picture should be consistent with the data
    ///   - width: The texture width, must be greater than 0.
    ///   - height: The texture height, must be greater than 0.
    ///   - sampleCount: The number of samples in the texture to create.
    ///   - device: Device information to create other objects.
    /// - Returns: New metal texture.
    public static func renderTexture(pixelFormat: MTLPixelFormat = MTLPixelFormat.rgba8Unorm,
                                     width: Int, height: Int,
                                     sampleCount: Int = 4,
                                     device: MTLDevice? = nil) throws -> MTLTexture {
        let width  = max(1, width)
        let height = max(1, height)
        let sampleDescriptor = MTLTextureDescriptor()
        sampleDescriptor.textureType = MTLTextureType.type2DMultisample
        sampleDescriptor.width = width
        sampleDescriptor.height = height
        sampleDescriptor.sampleCount = sampleCount
        sampleDescriptor.pixelFormat = pixelFormat
        #if !os(macOS) && !targetEnvironment(macCatalyst)
        sampleDescriptor.storageMode = .memoryless
        #endif
        sampleDescriptor.usage = .renderTarget
        let device = device ?? Device.device()
        guard let texture = device.makeTexture(descriptor: sampleDescriptor) else {
            throw CustomError.createRenderMTLTexture
        }
        return texture
    }
    
    /// Maximum metal texture size that can be processed.
    /// - Parameters:
    ///   - desiredSize: Metal textures size to be processed.
    ///   - device: Device information to create other objects.
    /// - Returns: New metal texture size.
    public static func maxTextureSize(desiredSize: MTLSize, device: MTLDevice? = nil) -> MTLSize {
        func supportsOnly8K() -> Bool {
            let device = device ?? Device.device()
            #if targetEnvironment(macCatalyst)
            return !device.supportsFamily(.apple3)
            #elseif os(macOS)
            return false
            #else
            if #available(iOS 13.0, *) {
                return !device.supportsFamily(.apple3)
            } else if #available(iOS 11.0, *)  {
                return !device.supportsFeatureSet(.iOS_GPUFamily3_v3)
            } else {
                return false
            }
            #endif
        }
        let maxSide: Int = supportsOnly8K() ? 8192 : 16_384
        guard desiredSize.width > 0, desiredSize.height > 0 else {
            return .init(width: 0, height: 0, depth: 0)
        }
        let aspectRatio = Float(desiredSize.width) / Float(desiredSize.height)
        if aspectRatio > 1 {
            let resultWidth = min(desiredSize.width, maxSide)
            let resultHeight = Float(resultWidth) / aspectRatio
            return MTLSize(width: resultWidth, height: Int(resultHeight.rounded()), depth: 0)
        } else {
            let resultHeight = min(desiredSize.height, maxSide)
            let resultWidth = Float(resultHeight) * aspectRatio
            return MTLSize(width: Int(resultWidth.rounded()), height: resultHeight, depth: 0)
        }
    }
}

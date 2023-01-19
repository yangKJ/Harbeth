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
    
    /// Create a CGImage with the data and information we provided.
    /// Each pixel contains of 4 UInt8s or 32 bits, each byte is representing one channel.
    /// The layout of the pixels is described with bitmap info.
    /// Process steps：Data => CFData => CGDataProvider => CGImage
    /// - Parameters:
    ///   - colorSpace: Color space
    ///   - pixelFormat: Current Metal texture pixel format.
    /// - Returns: CGImage
    public func toCGImage(colorSpace: CGColorSpace? = nil, pixelFormat: MTLPixelFormat? = nil) -> CGImage? {
        let region = MTLRegionMake3D(0, 0, 0, width, height, 1)
        switch pixelFormat ?? self.pixelFormat {
        case .a8Unorm, .r8Unorm, .r8Uint:
            let rowBytes = width
            let length = rowBytes * height
            let rgbaBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
            defer { rgbaBytes.deallocate() }
            getBytes(rgbaBytes, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
            
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
            getBytes(bgraBytes, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
            
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
            getBytes(rgbaBytes, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
            
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
    
    public func toImage() -> C7Image? {
        guard let cgImage = toCGImage() else { return nil }
        return cgImage.mt.toC7Image()
    }
}

extension MTLTexture {
    
    var size: C7Size {
        C7Size(width: self.width, height: self.height)
    }
    
    /// Create a texture with similar properties.
    func matchingTexture(to texture: MTLTexture) -> MTLTexture {
        let matchingDescriptor = MTLTextureDescriptor()
        matchingDescriptor.width = texture.width
        matchingDescriptor.height = texture.height
        matchingDescriptor.usage = texture.usage
        matchingDescriptor.pixelFormat = texture.pixelFormat
        matchingDescriptor.storageMode = texture.storageMode
        
        let loader = Shared.shared.device?.textureLoader
        let matchingTexture = loader?.device.makeTexture(descriptor: matchingDescriptor)
        return matchingTexture ?? texture
    }
}

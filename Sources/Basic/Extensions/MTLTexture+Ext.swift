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

    /// 把零级纹理数据拷贝到 CPU 可见内存。
    ///
    /// shared 纹理可以直接读取；managed 和 private 纹理先经过 shared staging buffer，
    /// 确保 GPU 写入在统一内存与独立显存 Mac 上都对 CPU 可见。
    @discardableResult
    func copyBytes(to destination: UnsafeMutableRawPointer, bytesPerRow: Int) -> Bool {
        guard target.width > 0,
              target.height > 0,
              let bytesPerPixel = readbackBytesPerPixel,
              bytesPerRow >= target.width * bytesPerPixel else {
            return false
        }
        let region = MTLRegionMake2D(0, 0, target.width, target.height)
        if target.storageMode == .shared {
            target.getBytes(destination, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            return true
        }

        #if os(iOS) || os(tvOS)
        guard target.storageMode != .memoryless else {
            return false
        }
        #endif

        let usedBytesPerRow = target.width * bytesPerPixel
        let stagingBytesPerRow = TextureLoader.alignedBytesPerRow(
            minimum: usedBytesPerRow,
            pixelFormat: target.pixelFormat,
            device: target.device
        )
        let stagingLength = stagingBytesPerRow * target.height
        guard let stagingBuffer = target.device.makeBuffer(length: stagingLength, options: .storageModeShared),
              let commandQueue = target.device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            return false
        }
        blit.copy(
            from: target,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: .init(x: 0, y: 0, z: 0),
            sourceSize: .init(width: target.width, height: target.height, depth: 1),
            to: stagingBuffer,
            destinationOffset: 0,
            destinationBytesPerRow: stagingBytesPerRow,
            destinationBytesPerImage: stagingLength
        )
        blit.endEncoding()
        do {
            try commandBuffer.commitAndWaitUntilCompleted(identifier: "TextureReadback")
        } catch {
            return false
        }

        let stagingBytes = stagingBuffer.contents()
        for row in 0..<target.height {
            memcpy(
                destination.advanced(by: row * bytesPerRow),
                stagingBytes.advanced(by: row * stagingBytesPerRow),
                usedBytesPerRow
            )
        }
        return true
    }

    private var readbackBytesPerPixel: Int? {
        switch target.pixelFormat {
        case .a8Unorm, .r8Unorm, .r8Uint:
            return 1
        case .rgba8Unorm, .rgba8Unorm_srgb, .bgra8Unorm, .bgra8Unorm_srgb:
            return 4
        case .rgba16Float:
            return 8
        case .rgba32Float:
            return 16
        default:
            return nil
        }
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
            guard copyBytes(to: data, bytesPerRow: rowBytes) else { return false }
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
        guard copyBytes(to: data, bytesPerRow: rowBytes) else { return false }
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
    
    public func toImage(colorSpace: CGColorSpace? = nil, alphaType: AlphaType = .premultiplied) -> C7Image? {
        let cgImage = toCGImage(colorSpace: colorSpace, alphaType: alphaType)
        return cgImage?.c7.toC7Image()
    }
    
    public func fixImageOrientation(refImage: C7Image, colorSpace: CGColorSpace? = nil, alphaType: AlphaType = .premultiplied) throws -> C7Image {
        guard let cgImage = toCGImage(colorSpace: colorSpace, alphaType: alphaType) else {
            throw HarbethError.texture2Image
        }
        return cgImage.c7.drawing(refImage: refImage).c7.flattened()
    }
    
    /// Create a CGImage with the data and information we provided.
    /// 8-bit textures return RGBA8; floating-point textures retain their 16F/32F component precision.
    /// The layout of the pixels is described with bitmap info.
    /// Process steps: `Data -> CFData -> CGDataProvider -> CGImage`.
    /// - Parameters:
    ///   - colorSpace: Color space
    ///   - pixelFormat: Current Metal texture pixel format.
    ///   - alphaType: Alpha representation used by the resulting image.
    /// - Returns: CGImage
    public func toCGImage(colorSpace: CGColorSpace? = nil, pixelFormat: MTLPixelFormat? = nil, alphaType: AlphaType = .premultiplied) -> CGImage? {
        let width = target.width
        let height = target.height
        let currentFormat = pixelFormat ?? target.pixelFormat
        // For non-float formats, use the original direct approach
        switch currentFormat {
        case .a8Unorm, .r8Unorm, .r8Uint:
            let rowBytes = width
            let length = rowBytes * height
            let rgbaBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
            defer { rgbaBytes.deallocate() }
            guard copyBytes(to: rgbaBytes, bytesPerRow: rowBytes) else { return nil }
            
            let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceGray()
            let rawV = currentFormat == .a8Unorm ? CGImageAlphaInfo.alphaOnly.rawValue : CGImageAlphaInfo.none.rawValue
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
            guard copyBytes(to: bgraBytes, bytesPerRow: rowBytes) else { return nil }
            
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
            let colorSpace = colorSpace ?? HarbethContext.shared.colorSpace
            let bitmapInfo = CGBitmapInfo(rawValue: alphaType.cgImageAlphaInfoForRGBA.rawValue)
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
            guard copyBytes(to: rgbaBytes, bytesPerRow: rowBytes) else { return nil }
            
            let colorSpace = colorSpace ?? HarbethContext.shared.colorSpace
            let bitmapInfo = CGBitmapInfo(rawValue: alphaType.cgImageAlphaInfoForRGBA.rawValue)
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
        case .rgba16Float, .rgba32Float:
            let bitsPerComponent = currentFormat == .rgba16Float ? 16 : 32
            let bytesPerComponent = bitsPerComponent / 8
            let rowBytes = width * 4 * bytesPerComponent
            let length = rowBytes * height
            let rgbaBytes = UnsafeMutableRawPointer.allocate(
                byteCount: length,
                alignment: bytesPerComponent
            )
            defer { rgbaBytes.deallocate() }
            guard copyBytes(to: rgbaBytes, bytesPerRow: rowBytes) else { return nil }

            let resolvedColorSpace = colorSpace
                ?? CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
                ?? HarbethContext.shared.colorSpace
            let byteOrder: CGBitmapInfo = currentFormat == .rgba16Float
                ? .byteOrder16Little
                : .byteOrder32Little
            let bitmapInfo = CGBitmapInfo(rawValue:
                CGBitmapInfo.floatComponents.rawValue
                    | byteOrder.rawValue
                    | alphaType.cgImageAlphaInfoForRGBA.rawValue
            )
            guard let data = CFDataCreate(nil, rgbaBytes.assumingMemoryBound(to: UInt8.self), length),
                  let dataProvider = CGDataProvider(data: data) else {
                return nil
            }
            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerComponent * 4,
                bytesPerRow: rowBytes,
                space: resolvedColorSpace,
                bitmapInfo: bitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
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
        guard copyBytes(to: buffer, bytesPerRow: rowBytes) else { return nil }
        if target.pixelFormat == .bgra8Unorm {
            // Convert in-place using vImage
            var src = vImage_Buffer(data: buffer, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            var dst = vImage_Buffer(data: buffer, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            let map: [UInt8] = [2, 1, 0, 3]
            vImagePermuteChannels_ARGB8888(&src, &dst, map, vImage_Flags(0))
        }
        return Data(bytes: buffer, count: totalBytes)
    }

    /// Uploads tightly packed host bytes into the current texture using Harbeth's
    /// alignment-safe texture replacement contract.
    public func replacePackedBytes(region: MTLRegion, mipmapLevel: Int = 0, bytes: [UInt8], packedBytesPerRow: Int) {
        TextureLoader.replaceTexture(
            target,
            region: region,
            mipmapLevel: mipmapLevel,
            bytes: bytes,
            packedBytesPerRow: packedBytesPerRow
        )
    }
}

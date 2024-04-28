//
//  TextureLoader.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import MetalKit
import CoreImage

/// Convert to metal texture Or create empty metal texture.
public struct TextureLoader {
    
    private static let usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
    /// Default create metal texture parameters.
    public static let defaultOptions = [
        .textureUsage: NSNumber(value: TextureLoader.usage.rawValue),
        .generateMipmaps: NSNumber(value: false),
        .SRGB: NSNumber(value: false)
    ] as [MTKTextureLoader.Option: Any]
    
    /// A metal texture.
    public let texture: MTLTexture
    
    /// Is it a blank texture?
    public var isBlank: Bool {
        texture.c7.isBlank()
    }
    
    public init(with texture: MTLTexture) {
        self.texture = texture
    }
    
    /// Creates a new MTLTexture from a given bitmap image.
    /// - Parameters:
    ///   - cgImage: Bitmap image
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with cgImage: CGImage, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        guard let loader = Shared.shared.device?.textureLoader else {
            throw HarbethError.textureLoader
        }
        let options = options ?? TextureLoader.defaultOptions
        self.texture = try loader.newTexture(cgImage: cgImage, options: options)
    }
    
    /// Creates a new MTLTexture from a CIImage.
    /// - Parameters:
    ///   - ciImage: CIImage
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with ciImage: CIImage, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        let options = options ?? TextureLoader.defaultOptions
        let context: CIContext? = {
            if options.keys.contains(where: { $0 == .sharedContext }) {
                return options[.sharedContext] as? CIContext
            }
            return nil
        }()
        guard let cgImage = ciImage.c7.toCGImage(context: context) else {
            throw HarbethError.source2Texture
        }
        try self.init(with: cgImage, options: options)
    }
    
    /// Creates a new MTLTexture from a CVPixelBuffer.
    /// - Parameters:
    ///   - ciImage: CVPixelBuffer
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with pixelBuffer: CVPixelBuffer, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        guard let cgImage = pixelBuffer.c7.toCGImage() else {
            throw HarbethError.source2Texture
        }
        let options = options ?? TextureLoader.defaultOptions
        try self.init(with: cgImage, options: options)
    }
    
    /// Creates a new MTLTexture from a CMSampleBuffer.
    /// - Parameters:
    ///   - ciImage: CVPixelBuffer
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with sampleBuffer: CMSampleBuffer, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw HarbethError.CMSampleBufferToCVPixelBuffer
        }
        let options = options ?? TextureLoader.defaultOptions
        try self.init(with: pixelBuffer, options: options)
    }
    
    /// Creates a new MTLTexture from a UIImage / NSImage.
    /// - Parameters:
    ///   - image: A UIImage / NSImage.
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with image: C7Image, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        guard let cgImage = image.c7.toCGImage() else {
            throw HarbethError.image2CGImage
        }
        let options = options ?? TextureLoader.defaultOptions
        try self.init(with: cgImage, options: options)
    }
    
    /// Creates a new MTLTexture from a Data.
    /// - Parameters:
    ///   - data: Data.
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with data: Data, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        guard let loader = Shared.shared.device?.textureLoader else {
            throw HarbethError.textureLoader
        }
        let options = options ?? TextureLoader.defaultOptions
        self.texture = try loader.newTexture(data: data, options: options)
    }
    
    #if os(macOS)
    /// Creates a new MTLTexture from a NSBitmapImageRep.
    /// - Parameters:
    ///   - bitmap: NSBitmapImageRep.
    ///   - pixelFormat: Indicates the pixelFormat, The format of the picture should be consistent with the data.
    public init(with bitmap: NSBitmapImageRep, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws {
        guard let data: UnsafeMutablePointer<UInt8> = bitmap.bitmapData else {
            throw HarbethError.bitmapDataNotFound
        }
        let texture = try TextureLoader.emptyTexture(width: Int(bitmap.size.width), height: Int(bitmap.size.height), options: [
            .texturePixelFormat: pixelFormat,
        ])
        let region = MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bitmap.bytesPerRow)
        self.texture = texture
    }
    #endif
}

// MARK: - create empty metal texture
extension TextureLoader {
    /// Create a new metal texture with options.
    public struct Option : Hashable, Equatable, RawRepresentable, @unchecked Sendable {
        public let rawValue: UInt16
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
    
    /// Create a new MTLTexture for later storage according to the texture parameters.
    /// - Parameters:
    ///   - size: The texture size.
    ///   - options: Configure other parameters about generating metal textures.
    public static func emptyTexture(at size: CGSize, options: [TextureLoader.Option: Any]? = nil) throws -> MTLTexture {
        try emptyTexture(width: Int(size.width), height: Int(size.height), options: options)
    }
    
    /// Create a new MTLTexture for later storage according to the texture parameters.
    /// - Parameters:
    ///   - width: The texture width, must be greater than 0, maximum resolution is 16384.
    ///   - height: The texture height, must be greater than 0, maximum resolution is 16384.
    ///   - options: Configure other parameters about generating metal textures.
    public static func emptyTexture(width: Int, height: Int, options: [TextureLoader.Option: Any]? = nil) throws -> MTLTexture {
        let options = options ?? [TextureLoader.Option: Any]()
        var usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
        var pixelFormat = MTLPixelFormat.rgba8Unorm
        var storageMode = MTLStorageMode.shared
        var allowGPUOptimizedContents = true
        #if os(macOS)
        // Texture Descriptor Validation MTLStorageModeShared not allowed for textures.
        // So macOS need use `managed`.
        storageMode = MTLStorageMode.managed
        #endif
        var sampleCount: Int = 1
        for (key, value) in options {
            switch (key, value) {
            case (.texturePixelFormat, let value as MTLPixelFormat):
                pixelFormat = value
            case (.textureUsage, let value as MTLTextureUsage):
                usage = value
            case (.textureStorageMode, let value as MTLStorageMode):
                storageMode = value
            case (.textureSampleCount, let value as Int):
                sampleCount = value
            case (.textureAllowGPUOptimizedContents, let value as Bool):
                allowGPUOptimizedContents = value
            default:
                break
            }
        }
        // Create a TextureDescriptor for a common 2D texture.
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: min(max(1, width), 16_384),
            height: min(max(1, height), 16_384),
            mipmapped: sampleCount == 1
        )
        descriptor.usage = usage
        descriptor.storageMode = storageMode
        descriptor.sampleCount = sampleCount
        descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
        if #available(iOS 12.0, macOS 10.14, *) {
            descriptor.allowGPUOptimizedContents = allowGPUOptimizedContents
        }
        guard let texture = Device.device().makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        return texture
    }
}

extension TextureLoader {
    /// Creates a new only read metal texture from a given bitmap image.
    /// - Parameter cgImage: Bitmap image
    public static func shaderReadTexture(with cgImage: CGImage) throws -> MTLTexture {
        let texturior = try TextureLoader.init(with: cgImage, options: [
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false)
        ])
        return texturior.texture
    }
    
    /// Copy a new metal texture.
    /// - Parameter texture: Texture to be copied.
    /// - Returns: New metal texture.
    public static func copyTexture(with texture: MTLTexture) throws -> MTLTexture {
        // 纹理最好不要又作为输入纹理又作为输出纹理，否则会出现重复内容，
        // 所以需要拷贝新的纹理来承载新的内容‼️
        return try TextureLoader.emptyTexture(width: texture.width, height: texture.height, options: [
            .texturePixelFormat: texture.pixelFormat,
            .textureUsage: texture.usage,
            .textureSampleCount: texture.sampleCount,
            .textureStorageMode: texture.storageMode,
        ])
    }
}

// MARK: - async convert to metal texture.
extension TextureLoader {
    
    /// Async convert to metal texture.
    /// - Parameters:
    ///   - cgImage: Bitmap image
    ///   - success: Successful
    ///   - failed: Failed
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public static func makeTexture(with cgImage: CGImage,
                                   options: [MTKTextureLoader.Option: Any]? = nil,
                                   success: @escaping (_ texture: MTLTexture) -> Void,
                                   failed: ((HarbethError) -> Void)? = nil) {
        let options = options ?? TextureLoader.defaultOptions
        guard let loader = Shared.shared.device?.textureLoader else {
            failed?(HarbethError.textureLoader)
            return
        }
        loader.newTexture(cgImage: cgImage, options: options) { texture, error in
            if let texture = texture {
                success(texture)
            } else if let error = error {
                failed?(HarbethError.error(error))
            }
        }
    }
    
    public static func makeTexture(with image: C7Image,
                                   options: [MTKTextureLoader.Option: Any]? = nil,
                                   success: @escaping (_ texture: MTLTexture) -> Void,
                                   failed: ((HarbethError) -> Void)? = nil) {
        let options = options ?? TextureLoader.defaultOptions
        guard let cgImage = image.cgImage else {
            failed?(HarbethError.source2Texture)
            return
        }
        makeTexture(with: cgImage, options: options, success: success, failed: failed)
    }
    
    public static func makeTexture(with ciImage: CIImage,
                                   options: [MTKTextureLoader.Option: Any]? = nil,
                                   success: @escaping (_ texture: MTLTexture) -> Void,
                                   failed: ((HarbethError) -> Void)? = nil) {
        let options = options ?? TextureLoader.defaultOptions
        let context: CIContext? = {
            if options.keys.contains(where: { $0 == .sharedContext }) {
                return options[.sharedContext] as? CIContext
            }
            return nil
        }()
        guard let cgImage = ciImage.c7.toCGImage(context: context) else {
            failed?(HarbethError.source2Texture)
            return
        }
        makeTexture(with: cgImage, options: options, success: success, failed: failed)
    }
}

extension MTKTextureLoader.Option {
    /// Shared context.
    static let sharedContext: MTKTextureLoader.Option = .init(rawValue: "condy_context")
}

extension TextureLoader.Option {
    
    /// Indicates the pixelFormat, The format of the picture should be consistent with the data.
    /// The default is `MTLPixelFormat.rgba8Unorm`.
    public static let texturePixelFormat: TextureLoader.Option = .init(rawValue: 1 << 1)
    
    /// Description of texture usage, default is `shaderRead` and `shaderWrite`.
    /// MTLTextureUsage declares how the texture will be used over its lifetime (bitwise OR for multiple uses).
    /// This information may be used by the driver to make optimization decisions.
    public static let textureUsage: TextureLoader.Option = .init(rawValue: 1 << 2)
    
    /// Describes location and CPU mapping of MTLTexture.
    /// In this mode, CPU and device will nominally both use the same underlying memory when accessing the contents of the texture resource.
    /// However, coherency is only guaranteed at command buffer boundaries to minimize the required flushing of CPU and GPU caches.
    /// This is the default storage mode for iOS Textures.
    public static let textureStorageMode: TextureLoader.Option = .init(rawValue: 1 << 3)
    
    /// The number of samples in the texture to create. The default value is 1.
    /// When creating Buffer textures sampleCount must be 1. Implementations may round sample counts up to the next supported value.
    public static let textureSampleCount: TextureLoader.Option = .init(rawValue: 1 << 4)
    
    /// Allow GPU-optimization for the contents of this texture. The default value is true.
    public static let textureAllowGPUOptimizedContents: TextureLoader.Option = .init(rawValue: 1 << 5)
}

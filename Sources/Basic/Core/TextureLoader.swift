//
//  TextureLoader.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import Metal
import MetalKit
import CoreImage

/// Converts various image sources into Metal textures or creates empty ones.
public struct TextureLoader {
    
    private static let defaultUsage: MTLTextureUsage = [.shaderRead, .shaderWrite]
    
    /// Default options for texture creation via MTKTextureLoader.
    public static let defaultOptions: [MTKTextureLoader.Option: Any] = [
        .textureUsage: NSNumber(value: defaultUsage.rawValue),
        .generateMipmaps: false,
        .SRGB: false,
        .textureCPUCacheMode: true,
    ]
    
    /// Optimized for read-only shader access (e.g., input textures).
    public static let shaderReadTextureOptions: [MTKTextureLoader.Option: Any] = [
        .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
        .generateMipmaps: false,
        .SRGB: false,
        .textureCPUCacheMode: true,
    ]
    
    public let texture: MTLTexture
    
    /// Is it a blank texture?
    public var isBlank: Bool {
        texture.c7.isBlank()
    }
    
    public init(with texture: MTLTexture) {
        self.texture = texture
    }
}

extension TextureLoader {
    
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
        PerformanceMonitor.shared.recordTextureCreation("texture_loader", created: true)
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
            return CIContext(mtlDevice: Device.device())
        }()
        guard let cgImage = context?.createCGImage(ciImage, from: ciImage.extent) else {
            throw HarbethError.source2Texture
        }
        try self.init(with: cgImage, options: options)
    }
    
    /// Creates a new MTLTexture from a CVPixelBuffer.
    /// - Parameters:
    ///   - ciImage: CVPixelBuffer
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with pixelBuffer: CVPixelBuffer, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        let pixelFormat = TextureLoader.pixelFormat(from: CVPixelBufferGetPixelFormatType(pixelBuffer))
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let texture = Device.device().makeTexture(descriptor: .texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )) else {
            throw HarbethError.textureLoader
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: baseAddress!, bytesPerRow: bytesPerRow)
        self.texture = texture
        PerformanceMonitor.shared.recordTextureCreation("pixelbuffer", created: true)
    }
    
    /// Creates a new MTLTexture from a CMSampleBuffer.
    /// - Parameters:
    ///   - ciImage: CVPixelBuffer
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with sampleBuffer: CMSampleBuffer, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw HarbethError.CMSampleBufferToCVPixelBuffer
        }
        try self.init(with: pixelBuffer, options: options)
    }
    
    /// Creates a new MTLTexture from a UIImage / NSImage.
    /// - Parameters:
    ///   - image: A UIImage / NSImage.
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with image: C7Image, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        if let ciImage = image.c7.toCIImage() {
            try self.init(with: ciImage, options: options)
        } else if let cgImage = image.cgImage {
            try self.init(with: cgImage, options: options)
        } else {
            throw HarbethError.image2CGImage
        }
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
        PerformanceMonitor.shared.recordTextureCreation("data", created: true)
    }
    
    #if os(macOS)
    /// Creates a new MTLTexture from a NSBitmapImageRep.
    /// - Parameters:
    ///   - bitmap: NSBitmapImageRep.
    ///   - pixelFormat: Indicates the pixelFormat, The format of the picture should be consistent with the data.
    public init(with bitmap: NSBitmapImageRep, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws {
        guard let data = bitmap.bitmapData else {
            throw HarbethError.bitmapDataNotFound
        }
        let texture = try TextureLoader.emptyTexture(
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            options: [.texturePixelFormat: pixelFormat]
        )
        let region = MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bitmap.bytesPerRow)
        self.texture = texture
        PerformanceMonitor.shared.recordTextureCreation("bitmap_rep", created: true)
    }
    #endif
}

extension TextureLoader {
    
    public struct Option: Hashable, Equatable, RawRepresentable, @unchecked Sendable {
        public let rawValue: UInt16
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
    
    /// Unified entry point for creating empty textures with pooling.
    /// - Parameters:
    ///   - width: The texture width, must be greater than 0, maximum resolution is 16384.
    ///   - height: The texture height, must be greater than 0, maximum resolution is 16384.
    ///   - options: Configure other parameters about generating metal textures.
    public static func makeTexture(width: Int, height: Int, options: [Option: Any]? = nil) throws -> MTLTexture {
        let opts = options ?? [:]
        let pixelFormat = opts[.texturePixelFormat] as? MTLPixelFormat ?? .rgba8Unorm
        let usage = opts[.textureUsage] as? MTLTextureUsage ?? defaultUsage
        let sampleCount = (opts[.textureSampleCount] as? Int) ?? 1
        let allowGPUOptimized = (opts[.textureAllowGPUOptimizedContents] as? Bool) ?? true
        // Platform-specific storage mode
        let storageMode: MTLStorageMode = {
            #if os(iOS) || targetEnvironment(simulator)
            return .shared
            #else
            // macOS requires `.managed` for CPU-accessible textures
            return usage.contains(.shaderWrite) ? .managed : .private
            #endif
        }()
        // Try texture pool first
        if let texture = Shared.shared.texturePool?.dequeueTexture(width: width, height: height, pixelFormat: pixelFormat) {
            PerformanceMonitor.shared.recordTextureCreation("texture_pool", created: false)
            return texture
        }
        // Create new descriptor
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
            descriptor.allowGPUOptimizedContents = allowGPUOptimized
        }
        guard let texture = Device.device().makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        PerformanceMonitor.shared.recordTextureCreation("texture_pool", created: true)
        return texture
    }
    
    public static func makeTexture(at size: CGSize, options: [Option: Any]? = nil) throws -> MTLTexture {
        return try makeTexture(width: Int(size.width), height: Int(size.height), options: options)
    }
    
    public static func emptyTexture(width: Int, height: Int, options: [Option: Any]? = nil) throws -> MTLTexture {
        try makeTexture(width: width, height: height, options: options)
    }
    
    public static func emptyTexture(at size: CGSize, options: [Option: Any]? = nil) throws -> MTLTexture {
        try makeTexture(at: size, options: options)
    }
    
    /// High-performance path: always uses pooling and minimal options.
    public static func makeOptimizedTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture {
        if let texture = Shared.shared.texturePool?.dequeueTexture(width: width, height: height, pixelFormat: pixelFormat) {
            PerformanceMonitor.shared.recordTextureCreation("texture_pool", created: false)
            return texture
        }
        return try makeTexture(width: width, height: height, options: [.texturePixelFormat: pixelFormat])
    }
}

extension TextureLoader {
    
    public static func shaderReadTexture(with cgImage: CGImage) throws -> MTLTexture {
        try TextureLoader(with: cgImage, options: shaderReadTextureOptions).texture
    }
    
    public static func copyTexture(with texture: MTLTexture) throws -> MTLTexture {
        // 纹理最好不要又作为输入纹理又作为输出纹理，否则会出现重复内容，
        // 所以需要拷贝新的纹理来承载新的内容‼️
        try makeTexture(width: texture.width, height: texture.height, options: [
            .texturePixelFormat: texture.pixelFormat,
            .textureUsage: texture.usage,
            .textureSampleCount: texture.sampleCount,
        ])
    }
    
    private static func pixelFormat(from cvFormat: OSType) -> MTLPixelFormat {
        switch cvFormat {
        case kCVPixelFormatType_32BGRA:
            return .bgra8Unorm
        case kCVPixelFormatType_32RGBA:
            return .rgba8Unorm
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            return .bgra8Unorm
        default:
            return .bgra8Unorm
        }
    }
}

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
        guard let loader = Shared.shared.device?.textureLoader else {
            failed?(.textureLoader)
            return
        }
        loader.newTexture(cgImage: cgImage, options: options ?? defaultOptions) { texture, error in
            if let texture = texture {
                PerformanceMonitor.shared.recordTextureCreation("async_texture", created: true)
                success(texture)
            } else if let error = error {
                failed?(.error(error))
            } else {
                failed?(.error(HarbethError.makeTexture))
            }
        }
    }
    
    public static func makeTexture(with image: C7Image,
                                   options: [MTKTextureLoader.Option: Any]? = nil,
                                   success: @escaping (_ texture: MTLTexture) -> Void,
                                   failed: ((HarbethError) -> Void)? = nil) {
        do {
            let texture = try TextureLoader(with: image, options: options).texture
            success(texture)
        } catch {
            failed?(.error(error))
        }
    }
    
    public static func makeTexture(with ciImage: CIImage,
                                   options: [MTKTextureLoader.Option: Any]? = nil,
                                   success: @escaping (_ texture: MTLTexture) -> Void,
                                   failed: ((HarbethError) -> Void)? = nil) {
        do {
            let texture = try TextureLoader(with: ciImage, options: options).texture
            success(texture)
        } catch {
            failed?(.error(error))
        }
    }
}

extension MTKTextureLoader.Option {
    /// Allows passing a shared `CIContext` for async CIImage conversion.
    public static let sharedContext = MTKTextureLoader.Option(rawValue: "condy_context")
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

//
//  TextureLoader.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import Metal
import MetalKit
import ImageIO
import CoreGraphics
import CoreVideo
import ObjectiveC

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

    /// 像素缓冲解析后的纹理源。
    ///
    /// 对于普通 RGBA pixel buffer，`planeTextures` 只包含主纹理；
    /// 对于 multi-plane YCbCr 输入，`primaryTexture` 仍保持轻量入口，
    /// 但 `planeTextures` 会把所有可直接桥接的 plane textures 一并暴露出来。
    public struct PixelBufferTextureSource {
        public let primaryTexture: MTLTexture
        public let planeTextures: [MTLTexture]
        public let bridgePlan: PixelBufferTextureBridgePlan

        public init(primaryTexture: MTLTexture,
                    planeTextures: [MTLTexture],
                    bridgePlan: PixelBufferTextureBridgePlan) {
            self.primaryTexture = primaryTexture
            self.planeTextures = planeTextures
            self.bridgePlan = bridgePlan
        }

        public var requiresPlaneAwareDecoding: Bool {
            bridgePlan.requiresColorConversion && planeTextures.count > 1
        }

        public var exposesAllDirectPlaneTextures: Bool {
            bridgePlan.directPlaneBridgeCount == planeTextures.count
                && bridgePlan.supportsDirectPlaneTextures
        }
    }
    
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
        let loader = Shared.shared.defaultDevice.textureLoader
        let options = options ?? TextureLoader.defaultOptions
        if let texture = try? loader.newTexture(cgImage: cgImage, options: options) {
            self.texture = texture
            return
        }
        // 降级策略：手动创建纹理并复制像素数据
        self.texture = try TextureLoader.drawCGImageToTexture(cgImage)
    }
    
    /// Creates a new MTLTexture from a CVPixelBuffer.
    /// - Parameters:
    ///   - ciImage: CVPixelBuffer
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with pixelBuffer: CVPixelBuffer, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        let source = try TextureLoader.resolveTextureSource(with: pixelBuffer, options: options)
        if source.requiresPlaneAwareDecoding {
            self.texture = try TextureLoader.decodeYCbCrTextureSource(source, owner: pixelBuffer)
        } else {
            self.texture = source.primaryTexture
        }
    }
    
    /// Creates a new MTLTexture from a CMSampleBuffer.
    /// - Parameters:
    ///   - ciImage: CVPixelBuffer
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with sampleBuffer: CMSampleBuffer, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        let source = try TextureLoader.resolveTextureSource(with: sampleBuffer, options: options)
        if source.requiresPlaneAwareDecoding {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                throw HarbethError.CMSampleBufferToCVPixelBuffer
            }
            self.texture = try TextureLoader.decodeYCbCrTextureSource(source, owner: pixelBuffer)
        } else {
            self.texture = source.primaryTexture
        }
    }
    
    /// Creates a new MTLTexture from a UIImage / NSImage.
    /// - Parameters:
    ///   - image: A UIImage / NSImage.
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with image: C7Image, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        if let cgImage = image.cgImage {
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
        let loader = Shared.shared.defaultDevice.textureLoader
        let options = options ?? TextureLoader.defaultOptions
        self.texture = try loader.newTexture(data: data, options: options)
    }

    public init(with data: Data,
                loadingOptions: ImageLoadingOptions,
                options: [MTKTextureLoader.Option: Any]? = nil) throws {
        let source = CGImageSourceCreateWithData(data as CFData, nil)
        guard let source else {
            throw HarbethError.source2Texture
        }
        let cgImage = try TextureLoader.loadCGImage(from: source, loadingOptions: loadingOptions)
        try self.init(with: cgImage, options: options)
    }

    public init(with url: URL,
                loadingOptions: ImageLoadingOptions = .default,
                options: [MTKTextureLoader.Option: Any]? = nil) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw HarbethError.source2Texture
        }
        let cgImage = try TextureLoader.loadCGImage(from: source, loadingOptions: loadingOptions)
        try self.init(with: cgImage, options: options)
    }

    public init(with asset: ImageAsset,
                options: [MTKTextureLoader.Option: Any]? = nil) throws {
        switch asset.storage {
        case .data(let data):
            try self.init(with: data, loadingOptions: asset.loadingOptions, options: options)
        case .url(let url):
            try self.init(with: url, loadingOptions: asset.loadingOptions, options: options)
        case .cgImage(let cgImage):
            let transformed = try TextureLoader.loadCGImage(from: cgImage, loadingOptions: asset.loadingOptions)
            try self.init(with: transformed, options: options)
        }
    }
    
    public init(with bundleURL: URL, name: String, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        let loader = Shared.shared.defaultDevice.textureLoader
        guard let assetBundle = Bundle(url: bundleURL),
              let imageURL = assetBundle.url(forResource: name, withExtension: nil) else {
            throw HarbethError.makeTexture
        }
        let options = options ?? TextureLoader.defaultOptions
        self.texture = try loader.newTexture(URL: imageURL, options: options)
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
        let texture = try TextureLoader.makeTexture(
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            options: [TextureLoader.Option.texturePixelFormat: pixelFormat]
        )
        let region = MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bitmap.bytesPerRow)
        self.texture = texture
    }
    #endif
}

extension TextureLoader {
    struct YCbCrDecodeStrategy {
        let layout: YCbCrPlaneDecodeFilter.Layout
        let conversionMatrix: Matrix3x3
        let conversionOffset: SIMD3<Float>
        let destinationPixelFormat: MTLPixelFormat
        let descriptor: String
        let matrixContract: YCbCrDecodeMatrix
    }

    public static func resolveTextureSource(with pixelBuffer: CVPixelBuffer,
                                            options: [MTKTextureLoader.Option: Any]? = nil) throws -> PixelBufferTextureSource {
        let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()
        switch bridgePlan.loadStrategy {
        case .directMetalTexture:
            guard let texture = pixelBuffer.c7.toMTLTexture() else {
                throw HarbethError.source2Texture
            }
            if bridgePlan.preservesOwnerReference {
                TextureOwnerRegistry.attach(pixelBuffer, to: texture)
            }
            return PixelBufferTextureSource(
                primaryTexture: texture,
                planeTextures: [texture],
                bridgePlan: bridgePlan
            )
        case .directPlaneTexture:
            #if targetEnvironment(simulator)
            guard let texture = pixelBuffer.c7.toMTLTexture() else {
                throw HarbethError.source2Texture
            }
            return PixelBufferTextureSource(
                primaryTexture: texture,
                planeTextures: [texture],
                bridgePlan: bridgePlan
            )
            #else
            let textures = pixelBuffer.c7.createPlaneTextures()
            if let primary = textures.first {
                TextureOwnerRegistry.attach(pixelBuffer, to: primary)
                return PixelBufferTextureSource(
                    primaryTexture: primary,
                    planeTextures: textures,
                    bridgePlan: bridgePlan
                )
            }
            guard let texture = pixelBuffer.c7.toMTLTexture() else {
                throw HarbethError.source2Texture
            }
            return PixelBufferTextureSource(
                primaryTexture: texture,
                planeTextures: [texture],
                bridgePlan: bridgePlan
            )
            #endif
        case .cgImageFallback:
            guard let cgImage = pixelBuffer.c7.toCGImage() else {
                throw HarbethError.source2Texture
            }
            let texture = try TextureLoader(with: cgImage, options: options).texture
            TextureOwnerRegistry.attach(pixelBuffer, to: texture)
            return PixelBufferTextureSource(
                primaryTexture: texture,
                planeTextures: [texture],
                bridgePlan: bridgePlan
            )
        case .cpuCopyFallback:
            let texture = try copyTextureFromPixelBuffer(pixelBuffer, bridgePlan: bridgePlan)
            return PixelBufferTextureSource(
                primaryTexture: texture,
                planeTextures: [texture],
                bridgePlan: bridgePlan
            )
        }
    }

    public static func resolveTextureSource(with sampleBuffer: CMSampleBuffer,
                                            options: [MTKTextureLoader.Option: Any]? = nil) throws -> PixelBufferTextureSource {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw HarbethError.CMSampleBufferToCVPixelBuffer
        }
        return try resolveTextureSource(with: pixelBuffer, options: options)
    }

    private static func copyTextureFromPixelBuffer(_ pixelBuffer: CVPixelBuffer,
                                                   bridgePlan: PixelBufferTextureBridgePlan) throws -> MTLTexture {
        let pixelFormat = bridgePlan.contract.preferredMetalPixelFormat
            ?? TextureLoader.pixelFormat(from: CVPixelBufferGetPixelFormatType(pixelBuffer))
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let texture = Shared.shared.metalDevice.makeTexture(descriptor: .texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )) else {
            throw HarbethError.textureLoader
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw HarbethError.source2Texture
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: baseAddress, bytesPerRow: bytesPerRow)
        TextureOwnerRegistry.attach(pixelBuffer, to: texture)
        return texture
    }

    static func makeYCbCrDecodeStrategy(for pixelBuffer: CVPixelBuffer,
                                        bridgePlan: PixelBufferTextureBridgePlan) -> YCbCrDecodeStrategy? {
        guard bridgePlan.requiresColorConversion else {
            return nil
        }
        let layout: YCbCrPlaneDecodeFilter.Layout
        switch bridgePlan.contract.colorModel {
        case .yCbCrBiPlanar:
            layout = .biPlanar
        case .yCbCrTriPlanar:
            layout = .triPlanar
        case .rgba, .monochrome, .unknown:
            return nil
        }
        let isFullRange = bridgePlan.contract.cvPixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            || bridgePlan.contract.cvPixelFormatType == kCVPixelFormatType_420YpCbCr8PlanarFullRange
        let conversionMatrix: Matrix3x3
        let descriptor: String
        if bridgePlan.contract.yCbCrMatrixAttachment == .ituR709_2 {
            conversionMatrix = Matrix3x3.Kernel.to709
            descriptor = isFullRange ? "709FullRangeApproximation" : "709VideoRange"
            let matrixContract: YCbCrDecodeMatrix = isFullRange ? .bt709FullRangeApproximation : .bt709VideoRange
            return YCbCrDecodeStrategy(
                layout: layout,
                conversionMatrix: conversionMatrix,
                conversionOffset: SIMD3<Float>(
                    isFullRange ? 0.0 : (-16.0 / 255.0),
                    -0.5,
                    -0.5
                ),
                destinationPixelFormat: .rgba8Unorm,
                descriptor: descriptor,
                matrixContract: matrixContract
            )
        } else if isFullRange {
            conversionMatrix = Matrix3x3.Kernel.to601FullRange
            descriptor = "601FullRange"
        } else {
            conversionMatrix = Matrix3x3.Kernel.to601
            descriptor = "601VideoRange"
        }
        return YCbCrDecodeStrategy(
            layout: layout,
            conversionMatrix: conversionMatrix,
            conversionOffset: SIMD3<Float>(
                isFullRange ? 0.0 : (-16.0 / 255.0),
                -0.5,
                -0.5
            ),
            destinationPixelFormat: .rgba8Unorm,
            descriptor: descriptor,
            matrixContract: isFullRange ? .bt601FullRange : .bt601VideoRange
        )
    }

    static func makeYCbCrDecodeContract(for pixelBuffer: CVPixelBuffer,
                                        bridgePlan: PixelBufferTextureBridgePlan) -> YCbCrDecodeContract? {
        guard let strategy = makeYCbCrDecodeStrategy(for: pixelBuffer, bridgePlan: bridgePlan) else {
            return nil
        }
        let layout: YCbCrPlaneLayout = strategy.layout == .biPlanar ? .biPlanar : .triPlanar
        return YCbCrDecodeContract(
            layout: layout,
            matrix: strategy.matrixContract,
            destinationPixelFormat: strategy.destinationPixelFormat
        )
    }

    static func makeBridgePolicy(for bridgePlan: PixelBufferTextureBridgePlan) -> PixelBufferBridgePolicy {
        if bridgePlan.requiresColorConversion && bridgePlan.directPlaneBridgeCount > 1 {
            return .directPlaneDecodeToRGBA
        }
        switch bridgePlan.loadStrategy {
        case .directMetalTexture:
            return .directTexturePassthrough
        case .directPlaneTexture:
            return .directPlanePassthrough
        case .cgImageFallback:
            return .cgImageMaterialization
        case .cpuCopyFallback:
            return .cpuCopyMaterialization
        }
    }

    private static func decodeYCbCrTextureSource(_ source: PixelBufferTextureSource,
                                                 owner: CVPixelBuffer) throws -> MTLTexture {
        guard let strategy = makeYCbCrDecodeStrategy(for: owner, bridgePlan: source.bridgePlan) else {
            return source.primaryTexture
        }
        let outputTexture = try makeTexture(
            width: source.bridgePlan.contract.width,
            height: source.bridgePlan.contract.height,
            options: [.texturePixelFormat: strategy.destinationPixelFormat],
            identifier: "YCbCrDecode"
        )
        let filter = YCbCrPlaneDecodeFilter(
            layout: strategy.layout,
            conversionMatrix: strategy.conversionMatrix,
            conversionOffset: strategy.conversionOffset,
            planeTextures: source.planeTextures
        )
        guard let commandBuffer = Shared.shared.commandQueue.makeCommandBuffer() else {
            throw HarbethError.commandBuffer
        }
        commandBuffer.label = "Harbeth.YCbCrDecode.\(strategy.descriptor)"
        _ = try filter.applyAtTexture(form: source.primaryTexture, to: outputTexture, for: commandBuffer)
        commandBuffer.commitAndWaitUntilCompleted(identifier: "YCbCrDecode")
        TextureOwnerRegistry.attach(owner, to: outputTexture)
        return outputTexture
    }

    
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
    public static func makeTexture(width: Int, height: Int, options: [Option: Any]? = nil, identifier: String = "Render") throws -> MTLTexture {
        let opts = options ?? [:]
        let pixelFormat = opts[.texturePixelFormat] as? MTLPixelFormat ?? .rgba8Unorm
        let usage = opts[.textureUsage] as? MTLTextureUsage ?? defaultUsage
        let sampleCount = (opts[.textureSampleCount] as? Int) ?? 1
        let allowGPUOptimized = (opts[.textureAllowGPUOptimizedContents] as? Bool) ?? true
        let allowsSizeTolerance = (opts[.textureAllowsSizeTolerance] as? Bool) ?? false
        // Platform-specific storage mode
        let storageMode: MTLStorageMode = {
            #if os(iOS) || targetEnvironment(simulator)
            return .shared
            #else
            // macOS requires `.managed` for CPU-accessible textures
            return usage.contains(.shaderWrite) ? .managed : .private
            #endif
        }()
        
        // Calculate size considering device limits
        let (maxWidth, maxHeight) = Device.makeTexture2DMaxSize(width: width, height: height)
        
        // Try texture pool with calculated size
        let pooledTexture: MTLTexture?
        if allowsSizeTolerance {
            pooledTexture = Shared.shared.defaultTexturePool.dequeueTexture(width: maxWidth, height: maxHeight, pixelFormat: pixelFormat)
        } else {
            pooledTexture = Shared.shared.defaultTexturePool.dequeueExactTexture(width: maxWidth, height: maxHeight, pixelFormat: pixelFormat)
        }
        if let texture = pooledTexture {
            Shared.shared.performanceMonitor?.recordTextureCreation(identifier, created: false)
            Shared.shared.performanceMonitor?.recordTextureReuse(identifier, source: "TexturePool")
            return texture
        }
        
        // Create new descriptor
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: max(maxWidth, 1),
            height: max(maxHeight, 1),
            mipmapped: sampleCount == 1
        )
        descriptor.usage = usage
        descriptor.storageMode = storageMode
        descriptor.sampleCount = sampleCount
        descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
        if #available(iOS 12.0, macOS 10.14, *) {
            descriptor.allowGPUOptimizedContents = allowGPUOptimized
        }
        guard let texture = Shared.shared.metalDevice.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        Shared.shared.performanceMonitor?.recordTextureCreation(identifier, created: true)
        Shared.shared.performanceMonitor?.recordRenderTargetCreation(identifier)
        return texture
    }

    /// Creates a texture lease whose lifetime controls when the texture is
    /// returned to the pool. This is the preferred API for texture-first frame
    /// renderers that need deterministic ownership.
    public static func makeTextureLease(width: Int,
                                        height: Int,
                                        options: [Option: Any]? = nil,
                                        identifier: String = "Render") throws -> TextureLease {
        let opts = options ?? [:]
        let pixelFormat = opts[.texturePixelFormat] as? MTLPixelFormat ?? .rgba8Unorm
        let allowsSizeTolerance = (opts[.textureAllowsSizeTolerance] as? Bool) ?? false
        let (maxWidth, maxHeight) = Device.makeTexture2DMaxSize(width: width, height: height)
        let logicalExtent = C7Size(width: max(maxWidth, 1), height: max(maxHeight, 1))

        if let lease = Shared.shared.defaultTextureAllocator.dequeueTextureLease(
            width: logicalExtent.width,
            height: logicalExtent.height,
            pixelFormat: pixelFormat,
            allowsSizeTolerance: allowsSizeTolerance,
            logicalExtent: logicalExtent
        ) {
            Shared.shared.performanceMonitor?.recordTextureCreation(identifier, created: false)
            Shared.shared.performanceMonitor?.recordTextureReuse(identifier, source: "TextureLease")
            return lease
        }

        let texture = try makeTexture(
            width: logicalExtent.width,
            height: logicalExtent.height,
            options: options,
            identifier: identifier
        )
        return Shared.shared.defaultTextureAllocator.makeLease(
            for: texture,
            logicalExtent: logicalExtent
        )
    }
    
    public static func makeTexture(at size: CGSize, options: [Option: Any]? = nil, identifier: String = "Render") throws -> MTLTexture {
        return try makeTexture(width: Int(size.width), height: Int(size.height), options: options, identifier: identifier)
    }
}

extension TextureLoader {
    
    public static func shaderReadTexture(with cgImage: CGImage) throws -> MTLTexture {
        try TextureLoader(with: cgImage, options: shaderReadTextureOptions).texture
    }
    
    public static func copyTexture(with texture: MTLTexture, identifier: String = "Render") throws -> MTLTexture {
        let width = texture.width, height = texture.height
        if let pooledTexture = Shared.shared.defaultTextureAllocator.dequeueTexture(
            width: width,
            height: height,
            pixelFormat: texture.pixelFormat,
            allowsSizeTolerance: true
        ) {
            Shared.shared.performanceMonitor?.recordTextureCreation(identifier, created: false)
            return pooledTexture
        }
        // 纹理最好不要又作为输入纹理又作为输出纹理，否则会出现重复内容，
        // 所以需要新的纹理来承载输出。返回给调用方的纹理不能同时入池，
        // 否则后续 dequeue 可能覆盖仍在使用或 GPU in-flight 的纹理。
        return try makeTexture(width: width, height: height, options: [
            .texturePixelFormat: texture.pixelFormat,
            .textureUsage: texture.usage,
            .textureSampleCount: texture.sampleCount,
        ], identifier: identifier)
    }
    
    private static func pixelFormat(from cvFormat: OSType) -> MTLPixelFormat {
        switch cvFormat {
        case kCVPixelFormatType_32BGRA:
            return .bgra8Unorm
        case kCVPixelFormatType_32RGBA:
            return .rgba8Unorm
        case kCVPixelFormatType_64RGBAHalf:
            return .rgba16Float
        case kCVPixelFormatType_OneComponent8:
            return .r8Unorm
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            return .bgra8Unorm
        default:
            return .bgra8Unorm
        }
    }

    private static func loadCGImage(from source: CGImageSource,
                                    loadingOptions: ImageLoadingOptions) throws -> CGImage {
        let cfOptions = makeImageSourceOptions(loadingOptions: loadingOptions)
        if loadingOptions.sizePolicy.resolvedMaxPixelSize() != nil,
           let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, cfOptions) {
            return try applyLoadingOptionsIfNeeded(to: thumbnail, loadingOptions: loadingOptions)
        }
        if let image = CGImageSourceCreateImageAtIndex(source, 0, cfOptions) {
            return try applyLoadingOptionsIfNeeded(to: image, loadingOptions: loadingOptions)
        }
        throw HarbethError.source2Texture
    }

    private static func loadCGImage(from cgImage: CGImage,
                                    loadingOptions: ImageLoadingOptions) throws -> CGImage {
        try applyLoadingOptionsIfNeeded(to: cgImage, loadingOptions: loadingOptions)
    }

    private static func makeImageSourceOptions(loadingOptions: ImageLoadingOptions) -> CFDictionary {
        var options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        if let maxPixelSize = loadingOptions.sizePolicy.resolvedMaxPixelSize() {
            options[kCGImageSourceCreateThumbnailFromImageAlways] = true
            options[kCGImageSourceThumbnailMaxPixelSize] = maxPixelSize
            options[kCGImageSourceCreateThumbnailWithTransform] = true
        }
        if loadingOptions.flipsVertically {
            options[kCGImageSourceCreateThumbnailWithTransform] = true
        }
        return options as CFDictionary
    }

    private static func applyLoadingOptionsIfNeeded(to cgImage: CGImage,
                                                    loadingOptions: ImageLoadingOptions) throws -> CGImage {
        let targetSize: CGSize = {
            switch loadingOptions.sizePolicy {
            case .original:
                return CGSize(width: cgImage.width, height: cgImage.height)
            case .maxPixelSize(let value):
                return CGSize(width: cgImage.width, height: cgImage.height).c7.constrained(
                    CGSize(width: max(value, 1), height: max(value, 1))
                )
            case .fit(let width, let height):
                return CGSize(width: cgImage.width, height: cgImage.height).c7.constrained(
                    CGSize(width: max(width, 1), height: max(height, 1))
                )
            }
        }()

        let outputWidth = max(Int(targetSize.width.rounded(.up)), 1)
        let outputHeight = max(Int(targetSize.height.rounded(.up)), 1)

        guard outputWidth != cgImage.width || outputHeight != cgImage.height || loadingOptions.flipsVertically else {
            return cgImage
        }

        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? Shared.shared.defaultDevice.colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw HarbethError.contextCreationFailed
        }

        if loadingOptions.flipsVertically {
            context.translateBy(x: 0, y: CGFloat(outputHeight))
            context.scaleBy(x: 1, y: -1)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        guard let image = context.makeImage() else {
            throw HarbethError.source2Texture
        }
        return image
    }
    
    /// Downgrade strategy: manually create textures and copy pixel data
    private static func drawCGImageToTexture(_ cgImage: CGImage) throws -> MTLTexture {
        let (width, height) = Device.makeTexture2DMaxSize(width: Int(cgImage.width), height: Int(cgImage.height))
        
        // 降级策略：手动创建纹理并复制像素数据
        let texture = try makeTexture(width: width, height: height, options: [
            .textureSampleCount: 1,
            .texturePixelFormat: MTLPixelFormat.rgba8Unorm,
            .textureUsage: defaultUsage,
            .textureAllowGPUOptimizedContents: true,
        ])
        
        let bytesPerRow = width * 4
        let dataSize = bytesPerRow * height
        let data = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 4)
        defer { data.deallocate() }
        
        guard let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: Shared.shared.defaultDevice.colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw HarbethError.contextCreationFailed
        }
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(cgImage, in: rect)
        
        // Copy data to texture
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
        
        return texture
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
                                   identifier: String = "Render",
                                   success: @escaping (_ texture: MTLTexture) -> Void,
                                   failed: ((HarbethError) -> Void)? = nil) {
        let loader = Shared.shared.defaultDevice.textureLoader
        loader.newTexture(cgImage: cgImage, options: options ?? defaultOptions) { texture, error in
            if let texture = texture {
                Shared.shared.performanceMonitor?.recordTextureCreation(identifier, created: true)
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

    /// Allows pooled texture reuse within the pool tolerance.
    /// The default is false for render-runtime correctness because geometry and mask
    /// coordinates must match the requested logical extent exactly.
    public static let textureAllowsSizeTolerance: TextureLoader.Option = .init(rawValue: 1 << 6)
}

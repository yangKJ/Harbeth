//
//  Texturior.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import MetalKit

/// New a metal texture.
public struct Texturior {
    
    /// Create a new metal texture with options.
    public struct Option : Hashable, Equatable, RawRepresentable, @unchecked Sendable {
        public let rawValue: UInt16
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
    
    /// A metal texture.
    public private(set) var texture: MTLTexture?
    
    /// Is it a blank texture?
    public var isBlank: Bool {
        guard let texture = texture else {
            return true
        }
        return texture.c7.isBlank()
    }
    
    /// Create a new MTLTexture for later storage according to the texture parameters.
    /// - Parameters:
    ///   - size: The texture size.
    ///   - options: Configure other parameters about generating metal textures.
    public init(size: CGSize, options: [Texturior.Option: Any]? = nil) {
        self.init(width: Int(size.width), height: Int(size.height), options: options)
    }
    
    /// Create a new MTLTexture for later storage according to the texture parameters.
    /// - Parameters:
    ///   - width: The texture width, must be greater than 0.
    ///   - height: The texture height, must be greater than 0.
    ///   - options: Configure other parameters about generating metal textures.
    public init(width: Int, height: Int, options: [Texturior.Option: Any]? = nil) {
        var usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
        var pixelFormat = MTLPixelFormat.rgba8Unorm
        var storageMode = MTLStorageMode.shared
        #if os(macOS)
        // Texture Descriptor Validation MTLStorageModeShared not allowed for textures.
        // So macOS need use `managed`.
        storageMode = MTLStorageMode.managed
        #endif
        var device: MTLDevice?
        for (key, value) in (options ?? [Texturior.Option: Any]()) {
            switch (key, value) {
            case (.texturePixelFormat, let value as MTLPixelFormat):
                pixelFormat = value
            case (.textureUsage, let value as MTLTextureUsage):
                usage = value
            case (.textureStorageMode, let value as MTLStorageMode):
                storageMode = value
            case (.textureDevice, let value as MTLDevice):
                device = value
            default:
                break
            }
        }
        // Create a TextureDescriptor for a common 2D texture.
        let descriptor = MTLTextureDescriptor.init()
        descriptor.width  = max(1, width)
        descriptor.height = max(1, height)
        descriptor.pixelFormat = pixelFormat
        descriptor.usage = usage
        descriptor.storageMode = storageMode
        self.texture = (device ?? Device.device()).makeTexture(descriptor: descriptor)
    }
}

extension Texturior {
    
    /// Copy a new metal texture.
    /// - Parameter texture: Texture to be copied.
    /// - Returns: New metal texture.
    public static func copyTexture(with texture: MTLTexture) throws -> MTLTexture {
        // 纹理最好不要又作为输入纹理又作为输出纹理，否则会出现重复内容，
        // 所以需要拷贝新的纹理来承载新的内容‼️
        let texturior = Texturior(width: texture.width, height: texture.height, options: [
            .texturePixelFormat: texture.pixelFormat,
            .textureUsage: texture.usage,
        ])
        guard let copiedTexture = texturior.texture else {
            throw CustomError.makeTexture
        }
        return copiedTexture
    }
}

extension Texturior.Option {
    
    /// MTLDevice represents a processor capable of data parallel computations.
    public static let textureDevice: Texturior.Option = .init(rawValue: 1 << 0)
    
    /// Indicates the pixelFormat, The format of the picture should be consistent with the data.
    /// The default is `MTLPixelFormat.rgba8Unorm`.
    public static let texturePixelFormat: Texturior.Option = .init(rawValue: 1 << 1)
    
    /// Description of texture usage, default is `shaderRead` and `shaderWrite`.
    /// MTLTextureUsage declares how the texture will be used over its lifetime (bitwise OR for multiple uses).
    /// This information may be used by the driver to make optimization decisions.
    public static let textureUsage: Texturior.Option = .init(rawValue: 1 << 2)
    
    /// Describes location and CPU mapping of MTLTexture.
    /// In this mode, CPU and device will nominally both use the same underlying memory when accessing the contents of the texture resource.
    /// However, coherency is only guaranteed at command buffer boundaries to minimize the required flushing of CPU and GPU caches.
    /// This is the default storage mode for iOS Textures.
    public static let textureStorageMode: Texturior.Option = .init(rawValue: 1 << 3)
}

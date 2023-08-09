//
//  Descriptor.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import MetalKit

public struct Descriptor {
    
    /// Copy a new metal texture.
    /// - Parameter texture: Texture to be copied.
    /// - Returns: New metal texture.
    public static func copyTexture(with texture: MTLTexture) -> MTLTexture {
        let width  = texture.width
        let height = texture.height
        let pixelFormat = texture.pixelFormat
        let usage = texture.usage
        // 纹理最好不要又作为输入纹理又作为输出纹理，否则会出现重复内容，
        // 所以需要拷贝新的纹理来承载新的内容‼️
        return destTexture(pixelFormat, width: width, height: height, usage: usage)
    }
    
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
        descriptor.storageMode = .shared
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
}

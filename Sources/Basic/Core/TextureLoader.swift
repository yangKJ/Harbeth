//
//  TextureLoader.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation
import MetalKit
import CoreImage

/// Convert to metal texture.
public struct TextureLoader {
    
    /// A metal texture.
    public let texture: MTLTexture
    
    /// Creates a new MTLTexture from a given bitmap image.
    /// - Parameters:
    ///   - cgImage: Bitmap image
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with cgImage: CGImage, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        let usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
        let textureOptions: [MTKTextureLoader.Option: Any] = options ?? [
            .textureUsage: NSNumber(value: usage.rawValue),
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false)
        ]
        guard let loader = Shared.shared.device?.textureLoader else {
            throw CustomError.textureLoader
        }
        self.texture = try loader.newTexture(cgImage: cgImage, options: textureOptions)
    }
    
    /// Creates a new MTLTexture from a UIImage / NSImage.
    /// - Parameters:
    ///   - image: A UIImage / NSImage.
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with image: C7Image, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        guard let cgImage = image.cgImage/*, let texture = cgImage.c7.toTexture() */else {
            throw CustomError.source2Texture
        }
        //self.texture = texture
        try self.init(with: cgImage, options: options)
    }
    
    /// Creates a new MTLTexture from a CIImage.
    /// - Parameters:
    ///   - ciImage: CIImage
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public init(with ciImage: CIImage, options: [MTKTextureLoader.Option: Any]? = nil) throws {
        let context: CIContext? = {
            guard let options = options else {
                return nil
            }
            if options.keys.contains(where: { $0 == .sharedContext }) {
                return options[.sharedContext] as? CIContext
            }
            return nil
        }()
        guard let cgImage = ciImage.c7.toCGImage(context: context) else {
            throw CustomError.source2Texture
        }
        try self.init(with: cgImage, options: options)
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
}

// MARK: - async convert to metal texture.
extension TextureLoader {
    
    /// Async convert to metal texture.
    /// - Parameters:
    ///   - cgImage: Bitmap image
    ///   - success: Successful
    ///   - failed: Failed
    ///   - options: Dictonary of MTKTextureLoaderOptions.
    public static func toTexture(with cgImage: CGImage,
                                 options: [MTKTextureLoader.Option: Any]? = nil,
                                 success: @escaping (_ texture: MTLTexture) -> Void,
                                 failed: ((CustomError) -> Void)? = nil) {
        let usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
        let textureOptions: [MTKTextureLoader.Option: Any] = options ?? [
            .textureUsage: NSNumber(value: usage.rawValue),
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false)
        ]
        guard let loader = Shared.shared.device?.textureLoader else {
            failed?(CustomError.textureLoader)
            return
        }
        loader.newTexture(cgImage: cgImage, options: textureOptions) { texture, error in
            if let texture = texture {
                success(texture)
            } else if let error = error {
                failed?(CustomError.error(error))
            }
        }
    }
    
    public static func toTexture(with image: C7Image,
                                 options: [MTKTextureLoader.Option: Any]? = nil,
                                 success: @escaping (_ texture: MTLTexture) -> Void,
                                 failed: ((CustomError) -> Void)? = nil) {
        guard let cgImage = image.cgImage else {
            failed?(CustomError.source2Texture)
            return
        }
        toTexture(with: cgImage, options: options, success: success, failed: failed)
    }
    
    public static func toTexture(with ciImage: CIImage,
                                 options: [MTKTextureLoader.Option: Any]? = nil,
                                 success: @escaping (_ texture: MTLTexture) -> Void,
                                 failed: ((CustomError) -> Void)? = nil) {
        guard let cgImage = ciImage.cgImage else {
            failed?(CustomError.source2Texture)
            return
        }
        toTexture(with: cgImage, options: options, success: success, failed: failed)
    }
}

extension MTKTextureLoader.Option {
    /// Shared context.
    static let sharedContext: MTKTextureLoader.Option = .init(rawValue: "condy_context")
}

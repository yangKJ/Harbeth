//
//  HarbethSource.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation
@preconcurrency import Metal
import CoreGraphics
import CoreVideo
import CoreMedia

/// 高级 texture-first 渲染的统一输入面。
public enum HarbethSource {
    case texture(MTLTexture)
    case image(C7Image)
    case cgImage(CGImage)
    case pixelBuffer(CVPixelBuffer)
    case sampleBuffer(CMSampleBuffer)
    case data(Data)
    case asset(HarbethImageAsset)

    public func makeTexture() throws -> MTLTexture {
        switch self {
        case .texture(let texture):
            return texture
        case .image(let image):
            return try TextureLoader(with: image).texture
        case .cgImage(let image):
            return try TextureLoader(with: image).texture
        case .pixelBuffer(let pixelBuffer):
            if let texture = pixelBuffer.c7.toMTLTexture() {
                return texture
            }
            return try TextureLoader(with: pixelBuffer).texture
        case .sampleBuffer(let sampleBuffer):
            return try TextureLoader(with: sampleBuffer).texture
        case .data(let data):
            return try TextureLoader(with: data).texture
        case .asset(let asset):
            return try TextureLoader(with: asset).texture
        }
    }

    public var orientation: FrameOrientation {
        #if os(iOS) || os(tvOS) || os(watchOS)
        if case .image(let image) = self {
            switch image.imageOrientation {
            case .up: return .up
            case .down: return .down
            case .left: return .left
            case .right: return .right
            case .upMirrored: return .upMirrored
            case .downMirrored: return .downMirrored
            case .leftMirrored: return .leftMirrored
            case .rightMirrored: return .rightMirrored
            @unknown default: return .unknown
            }
        }
        #endif
        return .up
    }

    public var colorSpace: CGColorSpace? {
        switch self {
        case .cgImage(let image):
            return image.colorSpace
        case .asset(let asset):
            if case .cgImage(let image) = asset.storage {
                return image.colorSpace
            }
            return nil
        default:
            return nil
        }
    }

    public var alphaType: AlphaType {
        switch self {
        case .cgImage(let image):
            return image.c7.alphaType
        #if os(iOS) || os(tvOS) || os(watchOS)
        case .image(let image):
            if let cgImage = image.cgImage {
                return cgImage.c7.alphaType
            }
            return .premultiplied
        #else
        case .image:
            return .premultiplied
        #endif
        case .asset(let asset):
            if case .cgImage(let image) = asset.storage {
                return image.c7.alphaType
            }
            return .premultiplied
        default:
            return .premultiplied
        }
    }

    public var cachePolicy: ImageCachePolicy {
        .persistent
    }

    public var kindName: String {
        switch self {
        case .texture: return "texture"
        case .image: return "image"
        case .cgImage: return "cgImage"
        case .pixelBuffer: return "pixelBuffer"
        case .sampleBuffer: return "sampleBuffer"
        case .data: return "data"
        case .asset(let asset): return asset.storage.kindName
        }
    }

    public var loadingOptions: ImageLoadingOptions {
        switch self {
        case .asset(let asset):
            return asset.loadingOptions
        case .texture, .image, .cgImage, .pixelBuffer, .sampleBuffer, .data:
            return .default
        }
    }

    public var sourceTier: ImageSourceTier {
        switch self {
        case .asset(let asset):
            return asset.sourceTier
        case .texture, .image, .cgImage, .pixelBuffer, .sampleBuffer, .data:
            return .original
        }
    }

    public var descriptor: HarbethSourceDescriptor {
        HarbethSourceDescriptor(
            kind: kindName,
            sourceTier: sourceTier,
            alphaType: alphaType,
            orientation: orientation,
            cachePolicy: cachePolicy,
            semantic: .sourceOriginal,
            loadingOptions: loadingOptions
        )
    }
}

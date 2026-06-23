//
//  ImageSource.swift
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
public enum ImageSource {
    case texture(MTLTexture)
    case image(C7Image)
    case cgImage(CGImage)
    case pixelBuffer(CVPixelBuffer)
    case sampleBuffer(CMSampleBuffer)
    case data(Data)
    case asset(ImageAsset)

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

    public var descriptor: ImageSourceDescriptor {
        switch self {
        case .pixelBuffer(let pixelBuffer):
            let bridgePlan = pixelBuffer.c7.makeTextureBridgePlan()
            return ImageSourceDescriptor(
                kind: kindName,
                sourceTier: sourceTier,
                alphaType: alphaType,
                orientation: orientation,
                cachePolicy: cachePolicy,
                semantic: .sourceOriginal,
                loadingOptions: loadingOptions,
                pixelBufferContract: pixelBuffer.c7.contract,
                pixelBufferBridgePlan: bridgePlan,
                pixelBufferBridgePolicy: TextureLoader.makeBridgePolicy(for: bridgePlan),
                yCbCrDecodeContract: TextureLoader.makeYCbCrDecodeContract(for: pixelBuffer, bridgePlan: bridgePlan)
            )
        case .sampleBuffer(let sampleBuffer):
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            let bridgePlan = pixelBuffer?.c7.makeTextureBridgePlan()
            return ImageSourceDescriptor(
                kind: kindName,
                sourceTier: sourceTier,
                alphaType: alphaType,
                orientation: orientation,
                cachePolicy: cachePolicy,
                semantic: .sourceOriginal,
                loadingOptions: loadingOptions,
                pixelBufferContract: pixelBuffer?.c7.contract,
                pixelBufferBridgePlan: bridgePlan,
                pixelBufferBridgePolicy: bridgePlan.map(TextureLoader.makeBridgePolicy(for:)),
                yCbCrDecodeContract: pixelBuffer.flatMap {
                    guard let bridgePlan else { return nil }
                    return TextureLoader.makeYCbCrDecodeContract(for: $0, bridgePlan: bridgePlan)
                },
                sampleBufferContract: sampleBuffer.c7.contract
            )
        default:
            return ImageSourceDescriptor(
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

    var resolutionFingerprint: String {
        switch self {
        case .texture(let texture):
            return [
                descriptor.fingerprint,
                "textureObject=\(ObjectIdentifier(texture).hashValue)",
                "size=\(texture.width)x\(texture.height)",
                "pixelFormat=\(texture.pixelFormat.rawValue)"
            ].joined(separator: "|")
        case .cgImage(let image):
            return [
                descriptor.fingerprint,
                "size=\(image.width)x\(image.height)"
            ].joined(separator: "|")
        case .data(let data):
            return [
                descriptor.fingerprint,
                "bytes=\(data.count)",
                "checksum=\(data.resolutionChecksum)"
            ].joined(separator: "|")
        case .asset(let asset):
            return [
                descriptor.fingerprint,
                asset.storage.resolutionFingerprint
            ].joined(separator: "|")
        case .image, .pixelBuffer, .sampleBuffer:
            return descriptor.fingerprint
        }
    }
}

private extension ImageAsset.Storage {
    var resolutionFingerprint: String {
        switch self {
        case .url(let url):
            return "url=\(url.absoluteString)"
        case .data(let data):
            return "data=\(data.count)|checksum=\(data.resolutionChecksum)"
        case .cgImage(let image):
            return "cgImage=\(image.width)x\(image.height)"
        }
    }
}

private extension Data {
    var resolutionChecksum: UInt64 {
        reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* UInt64(1_099_511_628_211)
        }
    }
}

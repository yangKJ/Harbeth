//
//  ImageSource.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation
@preconcurrency import Metal
import CoreGraphics
import CoreImage
import CoreVideo
import CoreMedia

/// 高级 texture-first 渲染的统一输入面。
public enum ImageSource {
    case texture(MTLTexture)
    case image(C7Image)
    case cgImage(CGImage)
    case ciImage(CIImage)
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
        case .ciImage(let image):
            return try TextureLoader(with: image).texture
        case .pixelBuffer(let pixelBuffer):
            if pixelBuffer.c7.makeTextureBridgePlan().loadStrategy == .directMetalTexture,
               let texture = pixelBuffer.c7.toMTLTexture() {
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
        case .ciImage(let image):
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
        case .ciImage:
            return .premultiplied
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
        .transient
    }

    public var kindName: String {
        switch self {
        case .texture: return "texture"
        case .image: return "image"
        case .cgImage: return "cgImage"
        case .ciImage: return "ciImage"
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
        case .texture, .image, .cgImage, .ciImage, .pixelBuffer, .sampleBuffer, .data:
            return .default
        }
    }

    public var sourceTier: ImageSourceTier {
        switch self {
        case .asset(let asset):
            return asset.sourceTier
        case .texture, .image, .cgImage, .ciImage, .pixelBuffer, .sampleBuffer, .data:
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

    var resolvedSizeHint: C7Size? {
        switch self {
        case .texture(let texture):
            return C7Size(texture: texture)
        case .cgImage(let image):
            return C7Size(cgImage: image)
        case .ciImage(let image):
            let extent = image.extent.integral
            guard extent.isNull == false, extent.isInfinite == false,
                  extent.width > 0, extent.height > 0 else {
                return nil
            }
            return C7Size(width: Int(extent.width), height: Int(extent.height))
        case .image(let image):
            let pixelWidth = max(Int((image.size.width * image.scale).rounded()), 1)
            let pixelHeight = max(Int((image.size.height * image.scale).rounded()), 1)
            return C7Size(width: pixelWidth, height: pixelHeight)
        case .pixelBuffer(let pixelBuffer):
            return C7Size(pixelBuffer: pixelBuffer)
        case .sampleBuffer(let sampleBuffer):
            return C7Size(sampleBuffer: sampleBuffer)
        case .data:
            return nil
        case .asset(let asset):
            switch asset.storage {
            case .cgImage(let image):
                return C7Size(cgImage: image)
            case .data, .url:
                return nil
            }
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
                "object=\(ObjectIdentifier(image).hashValue)",
                "size=\(image.width)x\(image.height)"
            ].joined(separator: "|")
        case .ciImage(let image):
            let extent = image.extent.integral
            return [
                descriptor.fingerprint,
                "object=\(ObjectIdentifier(image).hashValue)",
                "extent=\(extent.origin.x),\(extent.origin.y),\(extent.width),\(extent.height)"
            ].joined(separator: "|")
        case .image(let image):
            let objectIdentity = ObjectIdentifier(image).hashValue
            let pixelWidth = Int((image.size.width * image.scale).rounded())
            let pixelHeight = Int((image.size.height * image.scale).rounded())
            var parts = [
                descriptor.fingerprint,
                "object=\(objectIdentity)",
                "size=\(pixelWidth)x\(pixelHeight)",
                "scale=\(String(format: "%.4f", image.scale))"
            ]
            if let cgImage = image.cgImage {
                parts.append("cgObject=\(ObjectIdentifier(cgImage).hashValue)")
            }
            return parts.joined(separator: "|")
        case .pixelBuffer(let pixelBuffer):
            return [
                descriptor.fingerprint,
                "object=\(ObjectIdentifier(pixelBuffer).hashValue)"
            ].joined(separator: "|")
        case .sampleBuffer(let sampleBuffer):
            return [
                descriptor.fingerprint,
                "object=\(ObjectIdentifier(sampleBuffer).hashValue)"
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

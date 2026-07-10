//
//  TexturePyramid.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import CoreGraphics
import Foundation
import Metal

public struct TexturePyramidLevel {
    public let texture: MTLTexture
    public let pixelSize: C7Size
    public let logicalExtent: CGRect
    public let regionOrigin: CGPoint
    public let pixelScale: CGSize

    private let lease: TextureLease?

    init(texture: MTLTexture, logicalExtent: CGRect, regionOrigin: CGPoint, pixelScale: CGSize, lease: TextureLease?) {
        self.texture = texture
        self.pixelSize = C7Size(texture: texture)
        self.logicalExtent = logicalExtent
        self.regionOrigin = regionOrigin
        self.pixelScale = pixelScale
        self.lease = lease
    }

    public func release() {
        lease?.release()
    }
}

/// 由 level 0 逐级生成的、可复用的纹理金字塔。
///
/// 每一级都保留全局 logical extent、区域 origin 和像素缩放比例；区域输入只
/// 读取 `TextureRegionContext.readRegion`，不会要求持有整张原图的副本。
public final class TexturePyramid {
    public let levels: [TexturePyramidLevel]
    public let logicalExtent: CGRect
    public let regionOrigin: CGPoint

    public init(source: MTLTexture,
                region: TextureRegionContext? = nil,
                minimumSize: C7Size = C7Size(width: 1, height: 1),
                maxLevels: Int? = nil) throws {
        let minimum = C7Size(width: max(minimumSize.width, 1), height: max(minimumSize.height, 1))
        if let maxLevels, maxLevels < 1 {
            throw HarbethError.configurationInvalid("TexturePyramid.maxLevels must be at least 1")
        }

        let resolvedRegion: CGRect
        let resolvedExtent: CGRect
        let resolvedOrigin: CGPoint
        if let region {
            guard let rect = TextureRegionRect(rect: region.readRegion), rect.fits(in: source) else {
                throw HarbethError.textureCropFailed
            }
            resolvedRegion = region.readRegion
            resolvedExtent = region.logicalExtent
            resolvedOrigin = region.globalOrigin
        } else {
            resolvedRegion = CGRect(x: 0, y: 0, width: source.width, height: source.height)
            resolvedExtent = CGRect(x: 0, y: 0, width: source.width, height: source.height)
            resolvedOrigin = .zero
        }

        var builtLevels: [TexturePyramidLevel] = []
        let first: TexturePyramidLevel
        if region == nil {
            first = TexturePyramidLevel(
                texture: source,
                logicalExtent: resolvedExtent,
                regionOrigin: resolvedOrigin,
                pixelScale: CGSize(width: 1, height: 1),
                lease: nil
            )
        } else {
            let cropped = try HarbethIO(
                element: source,
                filter: C7CropBlit(rect: resolvedRegion)
            ).renderManagedTexture()
            first = TexturePyramidLevel(
                texture: cropped.texture,
                logicalExtent: resolvedExtent,
                regionOrigin: resolvedOrigin,
                pixelScale: CGSize(width: 1, height: 1),
                lease: cropped.lease
            )
        }
        builtLevels.append(first)

        var current = first
        while current.pixelSize.width > minimum.width || current.pixelSize.height > minimum.height {
            if let maxLevels, builtLevels.count >= maxLevels {
                break
            }
            let targetSize = C7Size(
                width: max(minimum.width, (current.pixelSize.width + 1) / 2),
                height: max(minimum.height, (current.pixelSize.height + 1) / 2)
            )
            if targetSize == current.pixelSize {
                break
            }
            let resized = try HarbethIO(
                element: current.texture,
                filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height))
            ).renderManagedTexture()
            let level = TexturePyramidLevel(
                texture: resized.texture,
                logicalExtent: resolvedExtent,
                regionOrigin: resolvedOrigin,
                pixelScale: CGSize(
                    width: CGFloat(resolvedRegion.width) / CGFloat(targetSize.width),
                    height: CGFloat(resolvedRegion.height) / CGFloat(targetSize.height)
                ),
                lease: resized.lease
            )
            builtLevels.append(level)
            current = level
        }

        self.levels = builtLevels
        self.logicalExtent = resolvedExtent
        self.regionOrigin = resolvedOrigin
    }

    public func upsample(_ level: TexturePyramidLevel, to targetSize: C7Size) throws -> TexturePyramidLevel {
        guard targetSize.width > 0, targetSize.height > 0 else {
            throw HarbethError.configurationInvalid("TexturePyramid target size must be positive")
        }
        let resized = try HarbethIO(
            element: level.texture,
            filter: C7Resize(width: Float(targetSize.width), height: Float(targetSize.height))
        ).renderManagedTexture()
        return TexturePyramidLevel(
            texture: resized.texture,
            logicalExtent: level.logicalExtent,
            regionOrigin: level.regionOrigin,
            pixelScale: CGSize(
                width: level.logicalExtent.width / CGFloat(targetSize.width),
                height: level.logicalExtent.height / CGFloat(targetSize.height)
            ),
            lease: resized.lease
        )
    }

    public func release() {
        levels.forEach { $0.release() }
    }

    deinit {
        release()
    }
}

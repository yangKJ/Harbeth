//
//  TextureDescriptorContract.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Metal

/// 纹理池内部使用的完整资源兼容键。
///
/// 宽高可以由 tolerant allocator 单独放宽，其他字段必须完全一致，
/// 避免把 storage、usage、sample 或 mipmap 合同不同的纹理错误复用。
struct TextureDescriptorContract: Hashable, @unchecked Sendable {
    let width: Int
    let height: Int
    let depth: Int
    let pixelFormatRawValue: UInt
    let textureTypeRawValue: UInt
    let mipmapLevelCount: Int
    let arrayLength: Int
    let sampleCount: Int
    let usageRawValue: UInt
    let storageModeRawValue: UInt
    let cpuCacheModeRawValue: UInt
    let hazardTrackingModeRawValue: UInt

    init(descriptor: MTLTextureDescriptor) {
        width = descriptor.width
        height = descriptor.height
        depth = descriptor.depth
        pixelFormatRawValue = descriptor.pixelFormat.rawValue
        textureTypeRawValue = descriptor.textureType.rawValue
        mipmapLevelCount = descriptor.mipmapLevelCount
        arrayLength = descriptor.arrayLength
        sampleCount = descriptor.sampleCount
        usageRawValue = descriptor.usage.rawValue
        storageModeRawValue = descriptor.storageMode.rawValue
        cpuCacheModeRawValue = descriptor.cpuCacheMode.rawValue
        let hazardTrackingMode: MTLHazardTrackingMode = descriptor.hazardTrackingMode == .default
            ? .tracked
            : descriptor.hazardTrackingMode
        hazardTrackingModeRawValue = hazardTrackingMode.rawValue
    }

    init(texture: MTLTexture) {
        width = texture.width
        height = texture.height
        depth = texture.depth
        pixelFormatRawValue = texture.pixelFormat.rawValue
        textureTypeRawValue = texture.textureType.rawValue
        mipmapLevelCount = texture.mipmapLevelCount
        arrayLength = texture.arrayLength
        sampleCount = texture.sampleCount
        usageRawValue = texture.usage.rawValue
        storageModeRawValue = texture.storageMode.rawValue
        cpuCacheModeRawValue = texture.cpuCacheMode.rawValue
        hazardTrackingModeRawValue = texture.hazardTrackingMode.rawValue
    }

    var pixelFormat: MTLPixelFormat {
        MTLPixelFormat(rawValue: pixelFormatRawValue) ?? .invalid
    }

    func isCompatible(with other: TextureDescriptorContract, sizeTolerance: Int) -> Bool {
        abs(width - other.width) <= sizeTolerance &&
        abs(height - other.height) <= sizeTolerance &&
        depth == other.depth &&
        pixelFormatRawValue == other.pixelFormatRawValue &&
        textureTypeRawValue == other.textureTypeRawValue &&
        mipmapLevelCount == other.mipmapLevelCount &&
        arrayLength == other.arrayLength &&
        sampleCount == other.sampleCount &&
        usageRawValue == other.usageRawValue &&
        storageModeRawValue == other.storageModeRawValue &&
        cpuCacheModeRawValue == other.cpuCacheModeRawValue &&
        hazardTrackingModeRawValue == other.hazardTrackingModeRawValue
    }
}

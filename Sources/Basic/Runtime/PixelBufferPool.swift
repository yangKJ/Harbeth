//
//  PixelBufferPool.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreVideo
import Metal

public struct RenderPixelBufferDescriptor: Sendable, Equatable, Hashable {
    public let width: Int
    public let height: Int
    public let pixelFormatType: OSType
    public let minimumBufferCount: Int
    public let allocationThreshold: Int?
    public let metalCompatible: Bool
    public let cgImageCompatible: Bool
    public let bitmapContextCompatible: Bool

    public init(width: Int,
                height: Int,
                pixelFormatType: OSType = kCVPixelFormatType_32BGRA,
                minimumBufferCount: Int = 2,
                allocationThreshold: Int? = nil,
                metalCompatible: Bool = true,
                cgImageCompatible: Bool = true,
                bitmapContextCompatible: Bool = true) {
        self.width = max(width, 1)
        self.height = max(height, 1)
        self.pixelFormatType = pixelFormatType
        self.minimumBufferCount = max(minimumBufferCount, 1)
        self.allocationThreshold = allocationThreshold
        self.metalCompatible = metalCompatible
        self.cgImageCompatible = cgImageCompatible
        self.bitmapContextCompatible = bitmapContextCompatible
    }

    public var fingerprint: String {
        [
            "size=\(width)x\(height)",
            "format=\(pixelFormatType)",
            "min=\(minimumBufferCount)",
            "threshold=\(allocationThreshold.map(String.init) ?? "none")",
            "metal=\(metalCompatible ? 1 : 0)",
            "cg=\(cgImageCompatible ? 1 : 0)",
            "bitmap=\(bitmapContextCompatible ? 1 : 0)"
        ].joined(separator: "|")
    }

    public static func pixelFormatType(for metalPixelFormat: MTLPixelFormat) -> OSType? {
        switch metalPixelFormat {
        case .bgra8Unorm, .bgra8Unorm_srgb:
            return kCVPixelFormatType_32BGRA
        case .rgba8Unorm, .rgba8Unorm_srgb:
            return kCVPixelFormatType_32RGBA
        case .r8Unorm:
            return kCVPixelFormatType_OneComponent8
        case .rgba16Float:
            return kCVPixelFormatType_64RGBAHalf
        default:
            return nil
        }
    }

    var poolAttributes: [String: Any] {
        [
            kCVPixelBufferPoolMinimumBufferCountKey as String: minimumBufferCount
        ]
    }

    var pixelBufferAttributes: [String: Any] {
        var attributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormatType,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        if metalCompatible {
            attributes[kCVPixelBufferMetalCompatibilityKey as String] = true
        }
        if cgImageCompatible {
            attributes[kCVPixelBufferCGImageCompatibilityKey as String] = true
        }
        if bitmapContextCompatible {
            attributes[kCVPixelBufferCGBitmapContextCompatibilityKey as String] = true
        }
        return attributes
    }
}

public struct RealtimePixelBufferPoolKey: Sendable, Hashable {
    public let width: Int
    public let height: Int
    public let pixelFormatType: OSType
    public let minimumBufferCount: Int
    public let usage: Int
    public let metalCompatible: Bool
    public let cgImageCompatible: Bool
    public let bitmapContextCompatible: Bool
    public let usesIOSurface: Bool

    public var realtimeIdentity: String {
        [
            "size=\(width)x\(height)",
            "format=\(pixelFormatType)",
            "min=\(minimumBufferCount)",
            "usage=\(usage)",
            "metal=\(metalCompatible ? 1 : 0)",
            "cg=\(cgImageCompatible ? 1 : 0)",
            "bitmap=\(bitmapContextCompatible ? 1 : 0)",
            "iosurface=\(usesIOSurface ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public enum RealtimePixelBufferPoolFallbackReason: Sendable, Equatable {
    case unsupportedPixelFormat
    case sizeMismatch
    case allocatorBusy
    case lruEvicted
    case unavailable
    case unknown
}

extension RenderPixelBufferDescriptor {
    var realtimePoolKey: RealtimePixelBufferPoolKey {
        RealtimePixelBufferPoolKey(
            width: width,
            height: height,
            pixelFormatType: pixelFormatType,
            minimumBufferCount: minimumBufferCount,
            usage: [
                metalCompatible ? 1 : 0,
                cgImageCompatible ? 2 : 0,
                bitmapContextCompatible ? 4 : 0
            ].reduce(0, +),
            metalCompatible: metalCompatible,
            cgImageCompatible: cgImageCompatible,
            bitmapContextCompatible: bitmapContextCompatible,
            usesIOSurface: pixelBufferAttributes.keys.contains(kCVPixelBufferIOSurfacePropertiesKey as String)
        )
    }
}

public final class PixelBufferPool {
    public let descriptor: RenderPixelBufferDescriptor
    private let pool: CVPixelBufferPool
    private static let realtimePoolQueue = DispatchQueue(label: "harbeth.realtime.pixelbufferpool")
    private static var realtimePoolStore: [String: CVPixelBufferPool] = [:]
    private static var realtimePoolLRUTimestamp: [String: Date] = [:]
    private static let realtimePoolMaxEntryCount = 4
    public static private(set) var realtimePoolHitCount: Int = 0
    public static private(set) var realtimePoolMissCount: Int = 0
    public static private(set) var realtimeAllocationFallbackCount: Int = 0

    public init(descriptor: RenderPixelBufferDescriptor) throws {
        self.descriptor = descriptor
        var createdPool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            descriptor.poolAttributes as CFDictionary,
            descriptor.pixelBufferAttributes as CFDictionary,
            &createdPool
        )
        guard status == kCVReturnSuccess, let createdPool else {
            throw HarbethError.pixelBufferCreationFailed
        }
        self.pool = createdPool
    }

    private init(descriptor: RenderPixelBufferDescriptor, pool: CVPixelBufferPool) {
        self.descriptor = descriptor
        self.pool = pool
    }

    public convenience init(width: Int,
                            height: Int,
                            pixelFormatType: OSType = kCVPixelFormatType_32BGRA,
                            minimumBufferCount: Int = 2,
                            allocationThreshold: Int? = nil) throws {
        try self.init(
            descriptor: RenderPixelBufferDescriptor(
                width: width,
                height: height,
                pixelFormatType: pixelFormatType,
                minimumBufferCount: minimumBufferCount,
                allocationThreshold: allocationThreshold
            )
        )
    }

    public func makePixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let auxAttributes: CFDictionary?
        if let allocationThreshold = descriptor.allocationThreshold {
            auxAttributes = [
                kCVPixelBufferPoolAllocationThresholdKey as String: allocationThreshold
            ] as CFDictionary
        } else {
            auxAttributes = nil
        }
        let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
            kCFAllocatorDefault,
            pool,
            auxAttributes,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw HarbethError.pixelBufferCreationFailed
        }
        return pixelBuffer
    }

    public static func acquire(for descriptor: RenderPixelBufferDescriptor, realtime: Bool) throws -> (buffer: CVPixelBuffer, poolUsed: Bool, fallbackReason: RealtimePixelBufferPoolFallbackReason?) {
        if descriptor.width <= 0 || descriptor.height <= 0 {
            return try realtimePoolQueue.sync {
                let result = try fallbackAcquisition(
                    for: RenderPixelBufferDescriptor(
                        width: max(descriptor.width, 1),
                        height: max(descriptor.height, 1),
                        pixelFormatType: descriptor.pixelFormatType,
                        minimumBufferCount: max(descriptor.minimumBufferCount, 1),
                        allocationThreshold: descriptor.allocationThreshold,
                        metalCompatible: descriptor.metalCompatible,
                        cgImageCompatible: descriptor.cgImageCompatible,
                        bitmapContextCompatible: descriptor.bitmapContextCompatible
                    ),
                    reason: .sizeMismatch,
                    pool: nil
                )
                realtimeAllocationFallbackCount += 1
                return result
            }
        }
        if isSupportedRealtimeFormat(descriptor.pixelFormatType) == false {
            return try realtimePoolQueue.sync {
                let fallbackDescriptor = RenderPixelBufferDescriptor(
                    width: descriptor.width,
                    height: descriptor.height,
                    pixelFormatType: kCVPixelFormatType_32BGRA,
                    minimumBufferCount: descriptor.minimumBufferCount,
                    allocationThreshold: descriptor.allocationThreshold,
                    metalCompatible: descriptor.metalCompatible,
                    cgImageCompatible: descriptor.cgImageCompatible,
                    bitmapContextCompatible: descriptor.bitmapContextCompatible
                )
                let result = try fallbackAcquisition(for: fallbackDescriptor, reason: .unsupportedPixelFormat, pool: nil)
                realtimeAllocationFallbackCount += 1
                return result
            }
        }

        guard realtime else {
            let pool = try PixelBufferPool(descriptor: descriptor)
            return (buffer: try pool.makePixelBuffer(), poolUsed: false, fallbackReason: nil)
        }
        let key = descriptor.realtimePoolKey.realtimeIdentity
        return try realtimePoolQueue.sync {
            if let cvPool = realtimePoolStore[key] {
                realtimePoolHitCount += 1
                realtimePoolLRUTimestamp[key] = Date()
                do {
                    let buffer = try PixelBufferPool(descriptor: descriptor, pool: cvPool).makePixelBuffer()
                    return (buffer: buffer, poolUsed: true, fallbackReason: nil)
                } catch {
                    realtimeAllocationFallbackCount += 1
                    return try fallbackAcquisition(for: descriptor, reason: .allocatorBusy, pool: cvPool)
                }
            }
            realtimePoolMissCount += 1
            let fallbackPool = try PixelBufferPool(descriptor: descriptor)
            let buffer = try fallbackPool.makePixelBuffer()
            var fallbackReason: RealtimePixelBufferPoolFallbackReason?
            if realtimePoolStore.count >= realtimePoolMaxEntryCount {
                fallbackReason = .lruEvicted
                realtimePoolLRUTimestamp
                    .sorted { $0.value < $1.value }
                    .first
                    .map { evicted in
                        realtimePoolStore.removeValue(forKey: evicted.key)
                        realtimePoolLRUTimestamp.removeValue(forKey: evicted.key)
                    }
            }
            realtimePoolStore[key] = fallbackPool.pool
            realtimePoolLRUTimestamp[key] = Date()
            return (buffer: buffer, poolUsed: true, fallbackReason: fallbackReason)
        }
    }

    public func acquire(realtime: Bool) throws -> (buffer: CVPixelBuffer, poolUsed: Bool, fallbackReason: RealtimePixelBufferPoolFallbackReason?) {
        try Self.acquire(for: descriptor, realtime: realtime)
    }

    public func flush(_ flags: CVPixelBufferPoolFlushFlags = []) {
        CVPixelBufferPoolFlush(pool, flags)
    }

    public static func resetRealtimePoolMetrics() {
        realtimePoolQueue.sync {
            realtimePoolHitCount = 0
            realtimePoolMissCount = 0
            realtimeAllocationFallbackCount = 0
        }
    }

    private static func isSupportedRealtimeFormat(_ format: OSType) -> Bool {
        [
            kCVPixelFormatType_32BGRA,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ].contains(format)
    }

    private static func fallbackAcquisition(for descriptor: RenderPixelBufferDescriptor, reason: RealtimePixelBufferPoolFallbackReason, pool: CVPixelBufferPool?) throws -> (CVPixelBuffer, Bool, RealtimePixelBufferPoolFallbackReason?) {
        let fallbackPool: PixelBufferPool
        if let pixelBufferPool = pool {
            fallbackPool = PixelBufferPool(descriptor: descriptor, pool: pixelBufferPool)
        } else {
            fallbackPool = try PixelBufferPool(descriptor: descriptor)
        }
        let buffer = try fallbackPool.makePixelBuffer()
        return (buffer, false, reason)
    }
}

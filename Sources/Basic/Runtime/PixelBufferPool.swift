//
//  PixelBufferPool.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreVideo

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

public final class PixelBufferPool {
    public let descriptor: RenderPixelBufferDescriptor
    private let pool: CVPixelBufferPool

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

    public func flush(_ flags: CVPixelBufferPoolFlushFlags = []) {
        CVPixelBufferPoolFlush(pool, flags)
    }
}

//
//  InverseCoordinateGrid.swift
//  Harbeth
//
//  Created by Condy on 2026/11/11.
//

import CoreGraphics
import CryptoKit
import Foundation
import Metal

/// A top-left-origin, normalized inverse sampling field with bilinear cells.
/// Editing transactions and brush semantics belong to the caller.
public struct InverseCoordinateGrid: Sendable {
    public let width: Int
    public let height: Int
    public let points: [CGPoint]
    private let fingerprintCache = GridFingerprintCache()

    public init(width: Int, height: Int, points: [CGPoint]) throws {
        guard (2...1024).contains(width), (2...1024).contains(height), points.count == width * height,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && Float($0.x).isFinite && Float($0.y).isFinite }) else {
            throw HarbethError.configurationInvalid("Inverse grids require finite points and matching dimensions.")
        }
        self.width = width
        self.height = height
        self.points = points
    }

    private var fingerprint: String {
        fingerprintCache.lock.lock()
        defer { fingerprintCache.lock.unlock() }
        if let cached = fingerprintCache.value { return cached }
        var data = Data(capacity: 8 + points.count * 8)
        for value in [UInt32(width), UInt32(height)] {
            var bits = value.littleEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
        for point in points {
            for value in [Float(point.x), Float(point.y)] {
                var bits = value.bitPattern.littleEndian
                withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
            }
        }
        let result = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        fingerprintCache.value = result
        return result
    }

    /// Uploads a numeric rg32Float field, reusing the context's bounded derived-resource cache.
    public func makeTexture() throws -> MTLTexture {
        let context = HarbethContext.shared
        let identity = context.makeDerivedResourceIdentity(domain: .coordinateField, fingerprint: fingerprint)
        return try context.makeDerivedTexture(for: identity) { try uploadTexture() }
    }

    /// Reuses an immutable producer revision without rebuilding or hashing its point array on hits.
    /// The identifier must change whenever the points change. Dimensions are part of the cache key.
    public static func makeTexture(
        width: Int,
        height: Int,
        identifier: String,
        points: () throws -> [CGPoint]
    ) throws -> MTLTexture {
        guard (2...1024).contains(width), (2...1024).contains(height), !identifier.isEmpty else {
            throw HarbethError.configurationInvalid("A versioned inverse grid requires valid dimensions and an identifier.")
        }
        let context = HarbethContext.shared
        let key = "InverseCoordinateGrid:v1:\(width)x\(height):\(identifier)"
        let identity = context.makeDerivedResourceIdentity(domain: .coordinateField, fingerprint: key)
        return try context.makeDerivedTexture(for: identity) {
            try InverseCoordinateGrid(width: width, height: height, points: points()).uploadTexture()
        }
    }

    private func uploadTexture() throws -> MTLTexture {
        let texture = try TextureLoader.makeTexture(
            width: width,
            height: height,
            options: [.texturePixelFormat: MTLPixelFormat.rg32Float],
            identifier: "InverseCoordinateGrid"
        )
        let values = points.flatMap { [Float($0.x), Float($0.y)] }
        values.withUnsafeBytes {
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: $0.baseAddress!,
                bytesPerRow: width * MemoryLayout<SIMD2<Float>>.stride
            )
        }
        return texture
    }

    /// Conservatively bounds all intersecting bilinear cells. Pixel rectangles use bottom-left
    /// coordinates, while grid points use top-left coordinates, matching inverse-grid rendering.
    public func sourceRegion(for rect: CGRect, extent: CGRect, padding: CGFloat = 2) -> CGRect {
        Self.sourceRegion(for: rect, extent: extent, width: width, height: height, padding: padding) { points[$0] }
    }

    /// Queries validated producer-owned points without copying or hashing the entire field.
    /// The producer must supply a point for every index in 0..<(width * height).
    public static func sourceRegion(
        for rect: CGRect,
        extent: CGRect,
        width: Int,
        height: Int,
        padding: CGFloat = 2,
        pointAt: (Int) -> CGPoint
    ) -> CGRect {
        guard (2...1024).contains(width), (2...1024).contains(height),
              [rect, extent].allSatisfy({ $0.minX.isFinite && $0.minY.isFinite && $0.maxX.isFinite && $0.maxY.isFinite }),
              extent.width > 0, extent.height > 0, padding.isFinite, padding >= 0 else { return .zero }
        let region = rect.intersection(extent)
        guard !region.isNull, region.width > 0, region.height > 0 else { return .zero }
        let columns = CGFloat(width - 1)
        let rows = CGFloat(height - 1)
        let left = max(0, Int(floor((region.minX - extent.minX) / extent.width * columns)))
        let right = min(width - 1, Int(ceil((region.maxX - extent.minX) / extent.width * columns)))
        let top = max(0, Int(floor((1 - (region.maxY - extent.minY) / extent.height) * rows)))
        let bottom = min(height - 1, Int(ceil((1 - (region.minY - extent.minY) / extent.height) * rows)))
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for y in top...max(top, bottom) {
            for x in left...max(left, right) {
                let point = pointAt(y * width + x)
                guard point.x.isFinite, point.y.isFinite else { return .zero }
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }
        return CGRect(
            x: extent.minX + minX * extent.width,
            y: extent.minY + (1 - maxY) * extent.height,
            width: (maxX - minX) * extent.width,
            height: (maxY - minY) * extent.height
        )
        .insetBy(dx: -padding, dy: -padding).integral.intersection(extent)
    }
}

private final class GridFingerprintCache: @unchecked Sendable {
    let lock = NSLock()
    var value: String?
}

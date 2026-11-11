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
        var data = Data()
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
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Uploads a numeric rg32Float field, reusing the context's bounded derived-resource cache.
    public func makeTexture() throws -> MTLTexture {
        let context = HarbethContext.shared
        let identity = context.makeDerivedResourceIdentity(domain: .coordinateField, fingerprint: fingerprint)
        return try context.makeDerivedTexture(for: identity) {
            let texture = try TextureLoader.makeTexture(
                width: width,
                height: height,
                options: [.texturePixelFormat: MTLPixelFormat.rg32Float],
                identifier: "InverseCoordinateGrid"
            )
            let values = points.flatMap { [Float($0.x), Float($0.y)] }
            values.withUnsafeBytes {
                texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                                withBytes: $0.baseAddress!, bytesPerRow: width * MemoryLayout<SIMD2<Float>>.stride)
            }
            return texture
        }
    }

    /// Conservatively bounds all intersecting bilinear cells. Pixel rectangles use bottom-left
    /// coordinates, while grid points use top-left coordinates, matching inverse-grid rendering.
    public func sourceRegion(for rect: CGRect, extent: CGRect, padding: CGFloat = 2) -> CGRect {
        guard [rect, extent].allSatisfy({ $0.minX.isFinite && $0.minY.isFinite && $0.maxX.isFinite && $0.maxY.isFinite }),
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
                let point = points[y * width + x]
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }
        return CGRect(x: extent.minX + minX * extent.width, y: extent.minY + (1 - maxY) * extent.height,
                      width: (maxX - minX) * extent.width, height: (maxY - minY) * extent.height)
            .insetBy(dx: -padding, dy: -padding).integral.intersection(extent)
    }
}

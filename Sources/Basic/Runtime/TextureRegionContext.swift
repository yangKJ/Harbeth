//
//  TextureRegionContext.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import CoreGraphics
import Foundation

/// 描述一次区域执行中的全局画布、读取范围和有效写回范围。
///
/// 所有矩形使用同一个全局像素坐标空间。`readRegion` 可以包含 halo，
/// `writeRegion` 只表示允许写回的有效区域。
public struct TextureRegionContext: Sendable, Equatable {
    public let logicalExtent: CGRect
    public let readRegion: CGRect
    public let writeRegion: CGRect
    public let globalOrigin: CGPoint

    public init(logicalExtent: CGRect, readRegion: CGRect, writeRegion: CGRect, globalOrigin: CGPoint? = nil) throws {
        guard Self.isFinite(logicalExtent), logicalExtent.width > 0, logicalExtent.height > 0 else {
            throw HarbethError.textureRegionInvalidLogicalExtent
        }
        guard Self.isFinite(readRegion), readRegion.width >= 0, readRegion.height >= 0,
              logicalExtent.contains(readRegion) else {
            throw HarbethError.textureRegionInvalidReadRegion
        }
        guard Self.isFinite(writeRegion), writeRegion.width >= 0, writeRegion.height >= 0,
              writeRegion.isEmpty || readRegion.contains(writeRegion) else {
            throw HarbethError.textureRegionInvalidWriteRegion
        }

        let resolvedOrigin = globalOrigin ?? readRegion.origin
        guard Self.isFinite(resolvedOrigin) else {
            throw HarbethError.textureRegionInvalidWriteRegion
        }

        self.logicalExtent = logicalExtent
        self.readRegion = readRegion
        self.writeRegion = writeRegion
        self.globalOrigin = resolvedOrigin
    }

    public init(logicalSize: C7Size) throws {
        let extent = CGRect(x: 0, y: 0, width: logicalSize.width, height: logicalSize.height)
        try self.init(logicalExtent: extent, readRegion: extent, writeRegion: extent)
    }

    /// 按固定 halo 扩大读取范围，并将其限制在逻辑画布内。
    public func expandingReadRegion(by radius: Int) throws -> TextureRegionContext {
        guard radius >= 0 else { throw HarbethError.textureRegionInvalidFootprint }
        let expanded = readRegion.insetBy(dx: -CGFloat(radius), dy: -CGFloat(radius))
        let clamped = expanded.intersection(logicalExtent)
        return try TextureRegionContext(
            logicalExtent: logicalExtent,
            readRegion: clamped,
            writeRegion: writeRegion,
            globalOrigin: globalOrigin
        )
    }

    /// 只有 point 或已知固定邻域可以自动解析成区域上下文。
    public func expandingReadRegion(for footprint: SamplingFootprint) throws -> TextureRegionContext {
        guard footprint.isValid else { throw HarbethError.textureRegionInvalidFootprint }
        guard let radius = footprint.haloRadius else {
            switch footprint {
            case .point:
                return self
            case .dynamic, .global:
                throw HarbethError.textureRegionUnsupportedFootprint
            case .neighborhood:
                throw HarbethError.textureRegionInvalidFootprint
            }
        }
        return try expandingReadRegion(by: radius)
    }

    private static func isFinite(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite &&
            rect.size.width.isFinite && rect.size.height.isFinite
    }

    private static func isFinite(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite
    }
}

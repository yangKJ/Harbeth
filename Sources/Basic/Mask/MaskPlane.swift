//
//  MaskPlane.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import CoreGraphics
import Foundation
import Metal

/// 蒙版坐标相对于哪一个逻辑画布解释。
public enum MaskCoordinateSpace: String, Sendable, Codable, Equatable, Hashable {
    case sourcePixels
    case sourceNormalized
    case outputPixels
}

/// coverage 纹理的采样方式。缩小时优先使用 `areaPreserving`，避免软边能量漂移。
public enum MaskSamplingFilter: String, Sendable, Codable, Equatable, Hashable {
    case nearest
    case linear
    case areaPreserving
}

public enum MaskSamplingEdgeMode: String, Sendable, Codable, Equatable, Hashable {
    case zero
    case clamp
    case mirror
}

public enum MaskCoverageSemantics: Sendable, Codable, Equatable, Hashable {
    case continuous
    case binary(threshold: Float)

    public var threshold: Float? {
        switch self {
        case .continuous: return nil
        case .binary(let threshold): return min(max(threshold.isFinite ? threshold : 0.5, 0), 1)
        }
    }
}

/// 避免把 CoreGraphics 的隐式坐标约定带入缓存、序列化与跨 tile 重基合同。
public struct MaskAffineTransform: Sendable, Codable, Equatable, Hashable {
    public let a: Float
    public let b: Float
    public let c: Float
    public let d: Float
    public let tx: Float
    public let ty: Float

    public init(a: Float = 1, b: Float = 0, c: Float = 0, d: Float = 1, tx: Float = 0, ty: Float = 0) {
        self.a = a.isFinite ? a : 1
        self.b = b.isFinite ? b : 0
        self.c = c.isFinite ? c : 0
        self.d = d.isFinite ? d : 1
        self.tx = tx.isFinite ? tx : 0
        self.ty = ty.isFinite ? ty : 0
    }

    public init(_ transform: CGAffineTransform) {
        self.init(
            a: Float(transform.a), b: Float(transform.b),
            c: Float(transform.c), d: Float(transform.d),
            tx: Float(transform.tx), ty: Float(transform.ty)
        )
    }

    public static let identity = MaskAffineTransform()

    public var cgAffineTransform: CGAffineTransform {
        CGAffineTransform(a: CGFloat(a), b: CGFloat(b), c: CGFloat(c), d: CGFloat(d), tx: CGFloat(tx), ty: CGFloat(ty))
    }

    public func applying(to point: CGPoint) -> CGPoint {
        point.applying(cgAffineTransform)
    }
}

public struct MaskSamplingContract: Sendable, Codable, Equatable, Hashable {
    public let filter: MaskSamplingFilter
    public let edgeMode: MaskSamplingEdgeMode
    public let pixelCentersAligned: Bool

    public init(filter: MaskSamplingFilter = .linear, edgeMode: MaskSamplingEdgeMode = .zero, pixelCentersAligned: Bool = true) {
        self.filter = filter
        self.edgeMode = edgeMode
        self.pixelCentersAligned = pixelCentersAligned
    }

    public static let softCoverage = MaskSamplingContract(filter: .areaPreserving, edgeMode: .zero)
    public static let binaryCoverage = MaskSamplingContract(filter: .nearest, edgeMode: .zero)
}

public struct MaskResourceIdentity: Sendable, Codable, Equatable, Hashable {
    public let identifier: String
    public let revision: UInt64
    public let generation: UInt64

    public init(identifier: String, revision: UInt64 = 0, generation: UInt64 = 0) {
        self.identifier = identifier
        self.revision = revision
        self.generation = generation
    }

    public func advanced(dirtyGeneration: UInt64? = nil) -> MaskResourceIdentity {
        MaskResourceIdentity(
            identifier: identifier,
            revision: revision &+ 1,
            generation: dirtyGeneration ?? generation
        )
    }

    public var fingerprint: String {
        "id=\(identifier)|revision=\(revision)|generation=\(generation)"
    }
}

/// 可序列化、可诊断的蒙版平面合同；不持有 Metal 对象。
public struct MaskPlaneDescriptor: Sendable, Codable, Equatable, Hashable {
    public let width: Int
    public let height: Int
    public let coordinateSpace: MaskCoordinateSpace
    public let sourceToMaskTransform: MaskAffineTransform
    public let sampling: MaskSamplingContract
    public let coverageSemantics: MaskCoverageSemantics
    public let storageFormat: MaskStorageFormat
    public let resourceIdentity: MaskResourceIdentity
    public let lastModifiedBounds: MaskCoverageBounds?

    public var fingerprint: String {
        let coverageValue = coverageSemantics.threshold.map { String($0) } ?? "continuous"
        let dirtyValue = lastModifiedBounds.map { "\($0.x),\($0.y),\($0.width),\($0.height)" } ?? "none"
        let parts: [String] = [
            "extent=\(width)x\(height)",
            "space=\(coordinateSpace.rawValue)",
            "transform=\(sourceToMaskTransform.a),\(sourceToMaskTransform.b),\(sourceToMaskTransform.c),\(sourceToMaskTransform.d),\(sourceToMaskTransform.tx),\(sourceToMaskTransform.ty)",
            "sampling=\(sampling.filter.rawValue):\(sampling.edgeMode.rawValue):\(sampling.pixelCentersAligned ? 1 : 0)",
            "coverage=\(coverageValue)",
            "storage=\(storageFormat.rawValue)",
            resourceIdentity.fingerprint,
            "dirty=\(dirtyValue)"
        ]
        return parts.joined(separator: "|")
    }
}

/// Harbeth 内统一的不可变 coverage 交付对象。
public struct MaskPlane: @unchecked Sendable {
    public let texture: MTLTexture
    public let descriptor: MaskPlaneDescriptor

    public init(texture: MTLTexture,
                coordinateSpace: MaskCoordinateSpace = .sourceNormalized,
                sourceToMaskTransform: MaskAffineTransform = .identity,
                sampling: MaskSamplingContract = .softCoverage,
                coverageSemantics: MaskCoverageSemantics = .continuous,
                storageFormat: MaskStorageFormat? = nil,
                resourceIdentity: MaskResourceIdentity? = nil,
                lastModifiedBounds: MaskCoverageBounds? = nil) {
        // descriptor 记录实际 texture storage；调用方 hint 不能覆盖 GPU 资源事实。
        let textureStorage = MaskStorageFormat(texture.pixelFormat)
        let resolvedStorage: MaskStorageFormat
        if let storageFormat, storageFormat.pixelFormat == texture.pixelFormat {
            resolvedStorage = storageFormat
        } else {
            resolvedStorage = textureStorage
        }
        let identity = resourceIdentity ?? MaskResourceIdentity(
            identifier: "texture:\(ObjectIdentifier(texture as AnyObject))"
        )
        self.texture = texture
        self.descriptor = MaskPlaneDescriptor(
            width: texture.width,
            height: texture.height,
            coordinateSpace: coordinateSpace,
            sourceToMaskTransform: sourceToMaskTransform,
            sampling: sampling,
            coverageSemantics: coverageSemantics,
            storageFormat: resolvedStorage,
            resourceIdentity: identity,
            lastModifiedBounds: lastModifiedBounds
        )
    }

    init(texture: MTLTexture, descriptor: MaskPlaneDescriptor) {
        self.texture = texture
        self.descriptor = MaskPlaneDescriptor(
            width: texture.width,
            height: texture.height,
            coordinateSpace: descriptor.coordinateSpace,
            sourceToMaskTransform: descriptor.sourceToMaskTransform,
            sampling: descriptor.sampling,
            coverageSemantics: descriptor.coverageSemantics,
            storageFormat: MaskStorageFormat(texture.pixelFormat),
            resourceIdentity: descriptor.resourceIdentity,
            lastModifiedBounds: descriptor.lastModifiedBounds
        )
    }

    public var width: Int { texture.width }
    public var height: Int { texture.height }

    public func maskDescriptor(component: MaskComponent = .red,
                               blendMode: MaskBlendMode = .mix,
                               invert: Bool = false,
                               featherPolicy: MaskFeatherPolicy = .none,
                               opacity: Float = 1) -> MaskDescriptor {
        MaskDescriptor(
            plane: self,
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    public func resampled(width: Int,
                          height: Int,
                          sampling override: MaskSamplingContract? = nil,
                          profile: RenderProfile = .stablePreview) throws -> MaskPlane {
        let targetWidth = max(width, 1)
        let targetHeight = max(height, 1)
        let resolvedSampling = override ?? descriptor.sampling
        guard targetWidth != texture.width || targetHeight != texture.height else {
            guard resolvedSampling != descriptor.sampling else { return self }
            return MaskPlane(
                texture: texture,
                coordinateSpace: descriptor.coordinateSpace,
                sourceToMaskTransform: descriptor.sourceToMaskTransform,
                sampling: resolvedSampling,
                coverageSemantics: descriptor.coverageSemantics,
                storageFormat: descriptor.storageFormat,
                resourceIdentity: descriptor.resourceIdentity,
                lastModifiedBounds: descriptor.lastModifiedBounds
            )
        }
        let normalized = try MaskProcessingRecipe(
            mask: MaskDescriptor(plane: self, component: .red)
        ).makeCoverageTexture()
        var io = HarbethIO(
            element: normalized,
            filter: MaskCoverageResample(
                width: targetWidth,
                height: targetHeight,
                filter: resolvedSampling.filter,
                edgeMode: resolvedSampling.edgeMode,
                binaryThreshold: descriptor.coverageSemantics.threshold
            )
        ).configured(for: profile)
        io.bufferPixelFormat = descriptor.storageFormat.pixelFormat
        let output = try io.output()

        let scaleX = Float(targetWidth) / Float(max(texture.width, 1))
        let scaleY = Float(targetHeight) / Float(max(texture.height, 1))
        let transform = descriptor.sourceToMaskTransform
        let scaledTransform = MaskAffineTransform(
            a: transform.a * scaleX,
            b: transform.b * scaleY,
            c: transform.c * scaleX,
            d: transform.d * scaleY,
            tx: transform.tx * scaleX,
            ty: transform.ty * scaleY
        )
        return MaskPlane(
            texture: output,
            coordinateSpace: descriptor.coordinateSpace,
            sourceToMaskTransform: scaledTransform,
            sampling: resolvedSampling,
            coverageSemantics: descriptor.coverageSemantics,
            storageFormat: descriptor.storageFormat,
            resourceIdentity: descriptor.resourceIdentity.advanced(),
            lastModifiedBounds: MaskCoverageBounds(x: 0, y: 0, width: targetWidth, height: targetHeight)
        )
    }
}

extension MaskStorageFormat {
    init(_ pixelFormat: MTLPixelFormat) {
        switch pixelFormat {
        case .r8Unorm: self = .coverage8
        case .r16Float: self = .coverage16Float
        case .rgba16Float: self = .rgba16Float
        default: self = .rgba8
        }
    }
}

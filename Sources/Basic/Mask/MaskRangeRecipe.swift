//
//  MaskRangeRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/19.
//

import Foundation
import Metal

public enum MaskRangeKind: Sendable, Codable, Equatable, Hashable {
    case luminance(lower: Float, upper: Float, softness: Float)
    case highlights(threshold: Float, softness: Float)
    case shadows(threshold: Float, softness: Float)
    case hue(center: Float, width: Float, softness: Float)
    case saturation(lower: Float, upper: Float, softness: Float)
    case colorDistance(red: Float, green: Float, blue: Float, tolerance: Float, softness: Float)

    var shaderParameters: [Float] {
        var values = [Float](repeating: 0, count: 8)
        switch self {
        case .luminance(let lower, let upper, let softness):
            values[0] = 0; values[1] = Self.unit(lower); values[2] = Self.unit(upper); values[3] = Self.unit(softness)
        case .highlights(let threshold, let softness):
            values[0] = 1; values[1] = Self.unit(threshold); values[3] = Self.unit(softness)
        case .shadows(let threshold, let softness):
            values[0] = 2; values[1] = Self.unit(threshold); values[3] = Self.unit(softness)
        case .hue(let center, let width, let softness):
            values[0] = 3; values[1] = Self.unit(center); values[2] = Self.unit(width); values[3] = Self.unit(softness)
        case .saturation(let lower, let upper, let softness):
            values[0] = 4; values[1] = Self.unit(lower); values[2] = Self.unit(upper); values[3] = Self.unit(softness)
        case .colorDistance(let red, let green, let blue, let tolerance, let softness):
            values[0] = 5; values[1] = Self.unit(red); values[2] = Self.unit(green); values[3] = Self.unit(blue)
            values[4] = Self.unit(tolerance); values[5] = Self.unit(softness)
        }
        return values
    }

    var fingerprint: String {
        shaderParameters.map { String(format: "%.5f", $0) }.joined(separator: ",")
    }

    private static func unit(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
/// Creates a mask from image tone or color ranges without attaching product semantics.
public struct MaskRangeRecipe {
    public let sourceTexture: MTLTexture
    public let sourceIdentifier: String
    public var kind: MaskRangeKind
    public var profile: RenderProfile
    public var storageFormat: MaskStorageFormat

    public init(sourceTexture: MTLTexture,
                sourceIdentifier: String,
                kind: MaskRangeKind,
                profile: RenderProfile = .stablePreview,
                storageFormat: MaskStorageFormat = .coverage8) {
        self.sourceTexture = sourceTexture
        self.sourceIdentifier = sourceIdentifier
        self.kind = kind
        self.profile = profile
        self.storageFormat = storageFormat
    }

    public var fingerprint: String {
        [
            "source=\(sourceIdentifier)",
            "size=\(sourceTexture.width)x\(sourceTexture.height)",
            "range=\(kind.fingerprint)",
            "storage=\(storageFormat.rawValue)",
            "profile=\(profile.rawValue)"
        ].joined(separator: "|")
    }

    public var graphDescriptor: MaskGraphDescriptor { graphDescriptor() }

    public func graphDescriptor(component: MaskComponent = .red,
                                blendMode: MaskBlendMode = .mix,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1) -> MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskRangeRecipe",
            fingerprint: fingerprint,
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: min(max(opacity, 0), 1),
            featherAmount: featherPolicy.amount,
            stepCount: 0,
            steps: [],
            gradient: nil,
            shape: nil,
            path: nil
        )
    }

    public func makeTexture() throws -> MTLTexture {
        var io = HarbethIO(element: sourceTexture, filter: RangeMask(kind: kind))
            .configured(for: profile)
        io.bufferPixelFormat = storageFormat.pixelFormat
        return try io.output()
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1) throws -> MaskDescriptor {
        MaskDescriptor(
            texture: try makeTexture(),
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }
}

/// Adapts an existing alpha, luma, depth, vector-rasterized, or other texture channel into a mask recipe.
public struct MaskTextureRecipe {
    public let texture: MTLTexture
    public let sourceIdentifier: String
    public var sourceComponent: MaskComponent
    public var profile: RenderProfile
    public var storageFormat: MaskStorageFormat

    public init(texture: MTLTexture,
                sourceIdentifier: String,
                sourceComponent: MaskComponent = .alpha,
                profile: RenderProfile = .stablePreview,
                storageFormat: MaskStorageFormat = .coverage8) {
        self.texture = texture
        self.sourceIdentifier = sourceIdentifier
        self.sourceComponent = sourceComponent
        self.profile = profile
        self.storageFormat = storageFormat
    }

    public var fingerprint: String {
        "source=\(sourceIdentifier)|size=\(texture.width)x\(texture.height)|component=\(sourceComponent.rawValue)|storage=\(storageFormat.rawValue)"
    }

    public var graphDescriptor: MaskGraphDescriptor { graphDescriptor() }

    public func graphDescriptor(component: MaskComponent = .red,
                                blendMode: MaskBlendMode = .mix,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1) -> MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskTextureRecipe",
            fingerprint: fingerprint,
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: min(max(opacity, 0), 1),
            featherAmount: featherPolicy.amount,
            stepCount: 0,
            steps: [],
            gradient: nil,
            shape: nil,
            path: nil
        )
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1) throws -> MaskDescriptor {
        var io = HarbethIO(
            element: texture,
            filter: MaskCoverageExtract(mask: MaskDescriptor(texture: texture, component: sourceComponent))
        ).configured(for: profile)
        io.bufferPixelFormat = storageFormat.pixelFormat
        return MaskDescriptor(
            texture: try io.output(),
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }
}

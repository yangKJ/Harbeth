//
//  MaskDescriptor.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation
import Metal

private func stableRecipeFloatDescription(_ value: Float) -> String {
    String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
}

public enum MaskComponent: Int, Sendable, Codable, Equatable, Hashable {
    case alpha = 0
    case red = 1
    case green = 2
    case blue = 3
    case luminance = 4
}

public enum MaskBlendMode: Int, Sendable, Codable, Equatable, Hashable {
    case mix = 0
    case replace = 1
    case add = 2
    case multiply = 3
    case subtract = 4
    case exclude = 5
}

public enum MaskFeatherPolicy: Sendable, Codable, Equatable, Hashable {
    case none
    case normalized(Float)

    var amount: Float {
        switch self {
        case .none:
            return 0
        case .normalized(let value):
            return min(max(value, 0), 1)
        }
    }
}

public struct MaskCompositeStepDescriptor: Sendable, Hashable, Codable {
    public let name: String
    public let component: MaskComponent
    public let blendMode: MaskBlendMode
    public let invert: Bool
    public let opacity: Float
    public let featherAmount: Float
    public let gradient: MaskGradientDescriptor?
    public let shape: MaskShapeDescriptor?
    public let path: MaskPathDescriptor?

    public var fingerprint: String {
        var parts = [
            "name=\(name)",
            "component=\(component.rawValue)",
            "blend=\(blendMode.rawValue)",
            "invert=\(invert ? 1 : 0)",
            "opacity=\(stableRecipeFloatDescription(opacity))",
            "feather=\(stableRecipeFloatDescription(featherAmount))"
        ]
        if let gradient {
            parts.append("gradient=\(gradient.fingerprint)")
        }
        if let shape {
            parts.append("shape=\(shape.fingerprint)")
        }
        if let path {
            parts.append("path=\(path.fingerprint)")
        }
        return parts.joined(separator: ",")
    }
}

public struct MaskGradientDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let fingerprint: String
    public let parameterValues: [String]
}

public struct MaskShapeDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let fingerprint: String
    public let parameterValues: [String]
}

public struct MaskPathDescriptor: Sendable, Hashable, Codable {
    public let fillRule: String
    public let fingerprint: String
    public let pointCount: Int
    public let subpathCount: Int
    public let parameterValues: [String]
}

public struct MaskGraphDescriptor: Sendable, Hashable, Codable {
    public let kind: String
    public let fingerprint: String
    public let component: MaskComponent
    public let blendMode: MaskBlendMode
    public let invert: Bool
    public let opacity: Float
    public let featherAmount: Float
    public let stepCount: Int
    public let steps: [MaskCompositeStepDescriptor]
    public let gradient: MaskGradientDescriptor?
    public let shape: MaskShapeDescriptor?
    public let path: MaskPathDescriptor?
}

public struct MaskDescriptor {
    public let texture: MTLTexture
    public var component: MaskComponent
    public var blendMode: MaskBlendMode
    public var invert: Bool
    public var featherPolicy: MaskFeatherPolicy
    public var opacity: Float

    public init(texture: MTLTexture,
                component: MaskComponent = .alpha,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0) {
        self.texture = texture
        self.component = component
        self.blendMode = blendMode
        self.invert = invert
        self.featherPolicy = featherPolicy
        self.opacity = min(max(opacity, 0), 1)
    }
}

extension MaskDescriptor {
    public var graphDescriptor: MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskDescriptor",
            fingerprint: [
                "component=\(component.rawValue)",
                "blend=\(blendMode.rawValue)",
                "invert=\(invert ? 1 : 0)",
                "opacity=\(stableRecipeFloatDescription(opacity))",
                "feather=\(stableRecipeFloatDescription(featherPolicy.amount))"
            ].joined(separator: ","),
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: opacity,
            featherAmount: featherPolicy.amount,
            stepCount: 0,
            steps: [],
            gradient: nil,
            shape: nil,
            path: nil
        )
    }
}

struct LocalEffectRecipeDescriptor: Sendable, Hashable, Codable {
    let filters: [FilterRecipeDescriptor]
    let mask: MaskGraphDescriptor
    let foregroundBlendMode: String?
    let foregroundBlendOpacity: Float

    init(filters: [FilterRecipeDescriptor], mask: MaskGraphDescriptor, foregroundBlendMode: String? = nil, foregroundBlendOpacity: Float = 1.0) {
        self.filters = filters
        self.mask = mask
        self.foregroundBlendMode = foregroundBlendMode
        self.foregroundBlendOpacity = foregroundBlendOpacity
    }

    var fingerprint: String {
        let chain = filters.isEmpty ? "none" : FilterChainRecipe(filters: filters).fingerprint
        return [
            "filters=\(chain)",
            "mask=\(mask.fingerprint)",
            "blend=\(foregroundBlendMode ?? "none")",
            "opacity=\(String(format: "%.4f", foregroundBlendOpacity))"
        ].joined(separator: "|")
    }
}

struct LayerMaskRecipeDescriptor: Sendable, Hashable, Codable {
    let layerIndex: Int
    let mask: MaskGraphDescriptor?
    let compositingMask: MaskGraphDescriptor?
}

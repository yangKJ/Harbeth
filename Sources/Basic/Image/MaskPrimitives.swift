//
//  MaskPrimitives.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreGraphics
import Metal

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

public enum MaskGradientKind: Sendable, Codable, Equatable, Hashable {
    case linear(startPoint: CGPoint, endPoint: CGPoint)
    case radial(center: CGPoint, startRadius: Float, endRadius: Float)

    var fingerprint: String {
        switch self {
        case .linear(let startPoint, let endPoint):
            return [
                "kind=linear",
                "start=\(String(format: "%.4f", startPoint.x)),\(String(format: "%.4f", startPoint.y))",
                "end=\(String(format: "%.4f", endPoint.x)),\(String(format: "%.4f", endPoint.y))"
            ].joined(separator: "|")
        case .radial(let center, let startRadius, let endRadius):
            return [
                "kind=radial",
                "center=\(String(format: "%.4f", center.x)),\(String(format: "%.4f", center.y))",
                "startRadius=\(String(format: "%.4f", startRadius))",
                "endRadius=\(String(format: "%.4f", endRadius))"
            ].joined(separator: "|")
        }
    }
}

public enum MaskShapeKind: Sendable, Codable, Equatable, Hashable {
    case rectangle(rect: CGRect, feather: Float = 0)
    case ellipse(rect: CGRect, feather: Float = 0)

    var fingerprint: String {
        switch self {
        case .rectangle(let rect, let feather):
            return [
                "kind=rectangle",
                "rect=\(String(format: "%.4f", rect.origin.x)),\(String(format: "%.4f", rect.origin.y)),\(String(format: "%.4f", rect.width)),\(String(format: "%.4f", rect.height))",
                "feather=\(String(format: "%.4f", min(max(feather, 0), 1)))"
            ].joined(separator: "|")
        case .ellipse(let rect, let feather):
            return [
                "kind=ellipse",
                "rect=\(String(format: "%.4f", rect.origin.x)),\(String(format: "%.4f", rect.origin.y)),\(String(format: "%.4f", rect.width)),\(String(format: "%.4f", rect.height))",
                "feather=\(String(format: "%.4f", min(max(feather, 0), 1)))"
            ].joined(separator: "|")
        }
    }
}

/// 参数化渐变遮罩。
///
/// 这层能力只负责把常见局部渐变选择沉成普通 texture：
/// - 线性渐变：`startPoint` 为 0 coverage，`endPoint` 为 1 coverage
/// - 径向渐变：`startRadius` 内为 1 coverage，`endRadius` 外为 0 coverage
/// - 输出仍是普通 `MaskDescriptor`，不引入重型 editor state
public struct MaskGradientRecipe {
    public var size: C7Size
    public var kind: MaskGradientKind
    public var profile: RenderProfile

    public init(size: C7Size, kind: MaskGradientKind, profile: RenderProfile = .stablePreview) {
        self.size = size
        self.kind = kind
        self.profile = profile
    }

    public var fingerprint: String {
        [
            "size=\(size.width)x\(size.height)",
            kind.fingerprint,
            "profile=\(profile.rawValue)"
        ].joined(separator: "|")
    }

    public var graphDescriptor: MaskGraphDescriptor {
        graphDescriptor()
    }

    public func graphDescriptor(component: MaskComponent = .red,
                                blendMode: MaskBlendMode = .mix,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1.0) -> MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskGradientRecipe",
            fingerprint: fingerprint,
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: min(max(opacity, 0), 1),
            featherAmount: featherPolicy.amount,
            stepCount: 0,
            steps: [],
            gradient: gradientDescriptor,
            shape: nil
        )
    }

    public var gradientDescriptor: MaskGradientDescriptor {
        switch kind {
        case .linear(let startPoint, let endPoint):
            return MaskGradientDescriptor(
                kind: "linear",
                fingerprint: fingerprint,
                parameterValues: [
                    "startX=\(Self.stableFloatDescription(Float(startPoint.x)))",
                    "startY=\(Self.stableFloatDescription(Float(startPoint.y)))",
                    "endX=\(Self.stableFloatDescription(Float(endPoint.x)))",
                    "endY=\(Self.stableFloatDescription(Float(endPoint.y)))",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        case .radial(let center, let startRadius, let endRadius):
            return MaskGradientDescriptor(
                kind: "radial",
                fingerprint: fingerprint,
                parameterValues: [
                    "centerX=\(Self.stableFloatDescription(Float(center.x)))",
                    "centerY=\(Self.stableFloatDescription(Float(center.y)))",
                    "startRadius=\(Self.stableFloatDescription(startRadius))",
                    "endRadius=\(Self.stableFloatDescription(endRadius))",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        }
    }

    public func makeTexture(pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture {
        let seed = try TextureLoader.makeTexture(
            width: max(size.width, 1),
            height: max(size.height, 1),
            options: [TextureLoader.Option.texturePixelFormat: pixelFormat],
            identifier: "MaskGradientRecipe"
        )
        return try HarbethIO(
            element: seed,
            filter: C7GradientMask(kind: kind)
        )
        .configured(for: profile)
        .output()
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0,
                                   pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor {
        MaskDescriptor(
            texture: try makeTexture(pixelFormat: pixelFormat),
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    static func stableFloatDescription(_ value: Float) -> String {
        C7GradientMask.stableFloatDescription(value)
    }
}

/// 参数化几何遮罩。
///
/// 这层能力把矩形/椭圆选择沉成普通 coverage texture，
/// 用 normalized rect + feather 表达，不引入更重的 editor state。
public struct MaskShapeRecipe {
    public var size: C7Size
    public var kind: MaskShapeKind
    public var profile: RenderProfile

    public init(size: C7Size, kind: MaskShapeKind, profile: RenderProfile = .stablePreview) {
        self.size = size
        self.kind = kind
        self.profile = profile
    }

    public var fingerprint: String {
        [
            "size=\(size.width)x\(size.height)",
            kind.fingerprint,
            "profile=\(profile.rawValue)"
        ].joined(separator: "|")
    }

    public var graphDescriptor: MaskGraphDescriptor {
        graphDescriptor()
    }

    public func graphDescriptor(component: MaskComponent = .red,
                                blendMode: MaskBlendMode = .mix,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1.0) -> MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskShapeRecipe",
            fingerprint: fingerprint,
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: min(max(opacity, 0), 1),
            featherAmount: featherPolicy.amount,
            stepCount: 0,
            steps: [],
            gradient: nil,
            shape: shapeDescriptor
        )
    }

    public var shapeDescriptor: MaskShapeDescriptor {
        switch kind {
        case .rectangle(let rect, let feather):
            return MaskShapeDescriptor(
                kind: "rectangle",
                fingerprint: fingerprint,
                parameterValues: [
                    "x=\(Self.stableFloatDescription(Float(rect.origin.x)))",
                    "y=\(Self.stableFloatDescription(Float(rect.origin.y)))",
                    "width=\(Self.stableFloatDescription(Float(rect.width)))",
                    "height=\(Self.stableFloatDescription(Float(rect.height)))",
                    "feather=\(Self.stableFloatDescription(feather))",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        case .ellipse(let rect, let feather):
            return MaskShapeDescriptor(
                kind: "ellipse",
                fingerprint: fingerprint,
                parameterValues: [
                    "x=\(Self.stableFloatDescription(Float(rect.origin.x)))",
                    "y=\(Self.stableFloatDescription(Float(rect.origin.y)))",
                    "width=\(Self.stableFloatDescription(Float(rect.width)))",
                    "height=\(Self.stableFloatDescription(Float(rect.height)))",
                    "feather=\(Self.stableFloatDescription(feather))",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        }
    }

    public func makeTexture(pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture {
        let seed = try TextureLoader.makeTexture(
            width: max(size.width, 1),
            height: max(size.height, 1),
            options: [TextureLoader.Option.texturePixelFormat: pixelFormat],
            identifier: "MaskShapeRecipe"
        )
        return try HarbethIO(
            element: seed,
            filter: C7ShapeMask(kind: kind)
        )
        .configured(for: profile)
        .output()
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0,
                                   pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MaskDescriptor {
        MaskDescriptor(
            texture: try makeTexture(pixelFormat: pixelFormat),
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    static func stableFloatDescription(_ value: Float) -> String {
        C7ShapeMask.stableFloatDescription(value)
    }
}

public struct LocalEffectRecipe {
    public var filters: [C7FilterProtocol]
    public var mask: MaskDescriptor
    public var maskRecipe: MaskCompositeRecipe?
    public var maskGraphOverride: MaskGraphDescriptor?

    public init(filters: [C7FilterProtocol], mask: MaskDescriptor) {
        self.filters = filters
        self.mask = mask
        self.maskRecipe = nil
        self.maskGraphOverride = nil
    }

    public init(filters: [C7FilterProtocol], maskRecipe: MaskCompositeRecipe) {
        self.filters = filters
        self.mask = maskRecipe.baseMask
        self.maskRecipe = maskRecipe
        self.maskGraphOverride = nil
    }

    public init(filters: [C7FilterProtocol],
                maskGradientRecipe: MaskGradientRecipe,
                component: MaskComponent = .red,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0) throws {
        self.filters = filters
        self.mask = try maskGradientRecipe.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.maskRecipe = nil
        self.maskGraphOverride = maskGradientRecipe.graphDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    public init(filters: [C7FilterProtocol],
                maskShapeRecipe: MaskShapeRecipe,
                component: MaskComponent = .red,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0) throws {
        self.filters = filters
        self.mask = try maskShapeRecipe.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.maskRecipe = nil
        self.maskGraphOverride = maskShapeRecipe.graphDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
    }

    func resolvedMaskDescriptor() throws -> MaskDescriptor {
        if let maskRecipe {
            return try maskRecipe.makeMaskDescriptor()
        }
        return mask
    }

    var recipeDescriptor: LocalEffectRecipeDescriptor {
        LocalEffectRecipeDescriptor(
            filters: filters.map(\.recipeDescriptor),
            mask: (maskGraphOverride ?? maskRecipe?.graphDescriptor) ?? mask.graphDescriptor
        )
    }
}

public struct MaskCompositeStep {
    public var name: String
    public var mask: MaskDescriptor
    public var gradientDescriptor: MaskGradientDescriptor?
    public var shapeDescriptor: MaskShapeDescriptor?

    public init(name: String = "mask",
                mask: MaskDescriptor,
                gradientDescriptor: MaskGradientDescriptor? = nil,
                shapeDescriptor: MaskShapeDescriptor? = nil) {
        self.name = name
        self.mask = mask
        self.gradientDescriptor = gradientDescriptor
        self.shapeDescriptor = shapeDescriptor
    }

    public var fingerprint: String {
        var parts = [
            "name=\(name)",
            "component=\(mask.component.rawValue)",
            "blend=\(mask.blendMode.rawValue)",
            "invert=\(mask.invert ? 1 : 0)",
            "opacity=\(String(format: "%.4f", mask.opacity))",
            "feather=\(mask.featherPolicy.amount)"
        ]
        if let gradientDescriptor {
            parts.append("gradient=\(gradientDescriptor.fingerprint)")
        }
        if let shapeDescriptor {
            parts.append("shape=\(shapeDescriptor.fingerprint)")
        }
        return parts.joined(separator: ",")
    }

    public var descriptor: MaskCompositeStepDescriptor {
        MaskCompositeStepDescriptor(
            name: name,
            component: mask.component,
            blendMode: mask.blendMode,
            invert: mask.invert,
            opacity: mask.opacity,
            featherAmount: mask.featherPolicy.amount,
            gradient: gradientDescriptor,
            shape: shapeDescriptor
        )
    }

    public static func add(_ mask: MaskDescriptor, name: String = "add") -> MaskCompositeStep {
        var descriptor = mask
        descriptor.blendMode = .add
        return MaskCompositeStep(name: name, mask: descriptor)
    }

    public static func intersect(_ mask: MaskDescriptor, name: String = "intersect") -> MaskCompositeStep {
        var descriptor = mask
        descriptor.blendMode = .multiply
        return MaskCompositeStep(name: name, mask: descriptor)
    }

    public static func subtract(_ mask: MaskDescriptor, name: String = "subtract") -> MaskCompositeStep {
        var descriptor = mask
        descriptor.blendMode = .subtract
        return MaskCompositeStep(name: name, mask: descriptor)
    }

    public static func add(_ maskGradientRecipe: MaskGradientRecipe,
                           component: MaskComponent = .red,
                           invert: Bool = false,
                           featherPolicy: MaskFeatherPolicy = .none,
                           opacity: Float = 1.0,
                           name: String = "add") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskGradientRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .add,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            gradientDescriptor: maskGradientRecipe.gradientDescriptor
        )
    }

    public static func intersect(_ maskGradientRecipe: MaskGradientRecipe,
                                 component: MaskComponent = .red,
                                 invert: Bool = false,
                                 featherPolicy: MaskFeatherPolicy = .none,
                                 opacity: Float = 1.0,
                                 name: String = "intersect") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskGradientRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .multiply,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            gradientDescriptor: maskGradientRecipe.gradientDescriptor
        )
    }

    public static func subtract(_ maskGradientRecipe: MaskGradientRecipe,
                                component: MaskComponent = .red,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1.0,
                                name: String = "subtract") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskGradientRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .subtract,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            gradientDescriptor: maskGradientRecipe.gradientDescriptor
        )
    }

    public static func add(_ maskShapeRecipe: MaskShapeRecipe,
                           component: MaskComponent = .red,
                           invert: Bool = false,
                           featherPolicy: MaskFeatherPolicy = .none,
                           opacity: Float = 1.0,
                           name: String = "add") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskShapeRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .add,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            shapeDescriptor: maskShapeRecipe.shapeDescriptor
        )
    }

    public static func intersect(_ maskShapeRecipe: MaskShapeRecipe,
                                 component: MaskComponent = .red,
                                 invert: Bool = false,
                                 featherPolicy: MaskFeatherPolicy = .none,
                                 opacity: Float = 1.0,
                                 name: String = "intersect") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskShapeRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .multiply,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            shapeDescriptor: maskShapeRecipe.shapeDescriptor
        )
    }

    public static func subtract(_ maskShapeRecipe: MaskShapeRecipe,
                                component: MaskComponent = .red,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1.0,
                                name: String = "subtract") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskShapeRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .subtract,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            shapeDescriptor: maskShapeRecipe.shapeDescriptor
        )
    }
}

public struct MaskCompositeRecipe {
    public var baseMask: MaskDescriptor
    public var baseGraphOverride: MaskGraphDescriptor?
    public var steps: [MaskCompositeStep]
    public var profile: RenderProfile

    public init(baseMask: MaskDescriptor, masks: [MaskDescriptor] = [], profile: RenderProfile = .stablePreview) {
        self.baseMask = baseMask
        self.baseGraphOverride = nil
        self.steps = masks.enumerated().map { index, mask in
            MaskCompositeStep(name: "mask\(index)", mask: mask)
        }
        self.profile = profile
    }

    public init(baseMask: MaskDescriptor, steps: [MaskCompositeStep], profile: RenderProfile = .stablePreview) {
        self.baseMask = baseMask
        self.baseGraphOverride = nil
        self.steps = steps
        self.profile = profile
    }

    public init(baseGradientRecipe: MaskGradientRecipe,
                component: MaskComponent = .red,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0,
                steps: [MaskCompositeStep] = []) throws {
        self.baseMask = try baseGradientRecipe.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.baseGraphOverride = baseGradientRecipe.graphDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.steps = steps
        self.profile = baseGradientRecipe.profile
    }

    public init(baseShapeRecipe: MaskShapeRecipe,
                component: MaskComponent = .red,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0,
                steps: [MaskCompositeStep] = []) throws {
        self.baseMask = try baseShapeRecipe.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.baseGraphOverride = baseShapeRecipe.graphDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.steps = steps
        self.profile = baseShapeRecipe.profile
    }

    public var maskCount: Int {
        1 + steps.count
    }

    public var masks: [MaskDescriptor] {
        steps.map(\.mask)
    }

    public func adding(_ mask: MaskDescriptor, name: String = "add") -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(.add(mask, name: name))
        return copy
    }

    public func intersecting(_ mask: MaskDescriptor, name: String = "intersect") -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(.intersect(mask, name: name))
        return copy
    }

    public func subtracting(_ mask: MaskDescriptor, name: String = "subtract") -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(.subtract(mask, name: name))
        return copy
    }

    public func adding(_ maskGradientRecipe: MaskGradientRecipe,
                       component: MaskComponent = .red,
                       invert: Bool = false,
                       featherPolicy: MaskFeatherPolicy = .none,
                       opacity: Float = 1.0,
                       name: String = "add") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .add(
                maskGradientRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func intersecting(_ maskGradientRecipe: MaskGradientRecipe,
                             component: MaskComponent = .red,
                             invert: Bool = false,
                             featherPolicy: MaskFeatherPolicy = .none,
                             opacity: Float = 1.0,
                             name: String = "intersect") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .intersect(
                maskGradientRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func subtracting(_ maskGradientRecipe: MaskGradientRecipe,
                            component: MaskComponent = .red,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            name: String = "subtract") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .subtract(
                maskGradientRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func adding(_ maskShapeRecipe: MaskShapeRecipe,
                       component: MaskComponent = .red,
                       invert: Bool = false,
                       featherPolicy: MaskFeatherPolicy = .none,
                       opacity: Float = 1.0,
                       name: String = "add") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .add(
                maskShapeRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func intersecting(_ maskShapeRecipe: MaskShapeRecipe,
                             component: MaskComponent = .red,
                             invert: Bool = false,
                             featherPolicy: MaskFeatherPolicy = .none,
                             opacity: Float = 1.0,
                             name: String = "intersect") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .intersect(
                maskShapeRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func subtracting(_ maskShapeRecipe: MaskShapeRecipe,
                            component: MaskComponent = .red,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            name: String = "subtract") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .subtract(
                maskShapeRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public var fingerprint: String {
        let baseSegment = [
            "base=1",
            "component=\(baseMask.component.rawValue)",
            "blend=\(baseMask.blendMode.rawValue)",
            "invert=\(baseMask.invert ? 1 : 0)",
            "opacity=\(String(format: "%.4f", baseMask.opacity))",
            "feather=\(baseMask.featherPolicy.amount)"
        ].joined(separator: ",")
        return [
            "profile=\(profile)",
            "base={\(baseSegment)}",
            "baseSource=\(baseGraphOverride?.fingerprint ?? "none")",
            "steps=\(steps.isEmpty ? "none" : steps.map(\.fingerprint).joined(separator: "||"))"
        ].joined(separator: "|")
    }

    public var graphDescriptor: MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskCompositeRecipe",
            fingerprint: fingerprint,
            component: baseMask.component,
            blendMode: baseMask.blendMode,
            invert: baseMask.invert,
            opacity: baseMask.opacity,
            featherAmount: baseMask.featherPolicy.amount,
            stepCount: steps.count,
            steps: steps.map(\.descriptor),
            gradient: baseGraphOverride?.gradient,
            shape: baseGraphOverride?.shape
        )
    }

    public func makeTexture() throws -> MTLTexture {
        var current = try HarbethIO(
            element: baseMask.texture,
            filter: C7MaskCoverageExtract(mask: baseMask)
        )
        .configured(for: profile)
        .output()

        for step in steps {
            current = try HarbethIO(
                element: current,
                filter: C7MaskCoverageBlend(baseComponent: .red, mask: step.mask)
            )
            .configured(for: profile)
            .output()
        }
        return current
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0) throws -> MaskDescriptor {
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

extension MaskDescriptor {
    public var graphDescriptor: MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskDescriptor",
            fingerprint: [
                "component=\(component.rawValue)",
                "blend=\(blendMode.rawValue)",
                "invert=\(invert ? 1 : 0)",
                "opacity=\(String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), opacity))",
                "feather=\(String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), featherPolicy.amount))"
            ].joined(separator: ","),
            component: component,
            blendMode: blendMode,
            invert: invert,
            opacity: opacity,
            featherAmount: featherPolicy.amount,
            stepCount: 0,
            steps: [],
            gradient: nil,
            shape: nil
        )
    }
}

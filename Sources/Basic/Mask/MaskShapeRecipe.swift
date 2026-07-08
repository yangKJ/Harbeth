//
//  MaskShapeRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation
import Metal

/// 参数化基础形状遮罩。
///
/// `MaskShapeRecipe` 是普通用户选择基础形状的首选入口。
/// rectangle / ellipse / roundedRect 走原生 analytic coverage，
/// regularPolygon / star 保持 shape 语义，当前版本内部 lower 到 path 执行。
public struct MaskShapeRecipe {
    public var size: C7Size
    public var kind: MaskShapeKind
    public var transform: MaskPathTransform
    public var profile: RenderProfile

    public init(size: C7Size, kind: MaskShapeKind, transform: MaskPathTransform = .identity, profile: RenderProfile = .stablePreview) {
        self.size = size
        self.kind = kind
        self.transform = transform
        self.profile = profile
    }

    public var fingerprint: String {
        [
            "size=\(size.width)x\(size.height)",
            kind.fingerprint,
            "transform={\(transform.fingerprint)}",
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
            shape: shapeDescriptor,
            path: nil
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
                    "transform=\(transform.fingerprint)",
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
                    "transform=\(transform.fingerprint)",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        case .roundedRect(let rect, let cornerRadius, let feather):
            return MaskShapeDescriptor(
                kind: "roundedRect",
                fingerprint: fingerprint,
                parameterValues: [
                    "x=\(Self.stableFloatDescription(Float(rect.origin.x)))",
                    "y=\(Self.stableFloatDescription(Float(rect.origin.y)))",
                    "width=\(Self.stableFloatDescription(Float(rect.width)))",
                    "height=\(Self.stableFloatDescription(Float(rect.height)))",
                    "cornerRadius=\(Self.stableFloatDescription(cornerRadius))",
                    "feather=\(Self.stableFloatDescription(feather))",
                    "transform=\(transform.fingerprint)",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        case .regularPolygon(let rect, let sides, let feather):
            return MaskShapeDescriptor(
                kind: "regularPolygon",
                fingerprint: fingerprint,
                parameterValues: [
                    "x=\(Self.stableFloatDescription(Float(rect.origin.x)))",
                    "y=\(Self.stableFloatDescription(Float(rect.origin.y)))",
                    "width=\(Self.stableFloatDescription(Float(rect.width)))",
                    "height=\(Self.stableFloatDescription(Float(rect.height)))",
                    "sides=\(max(sides, 3))",
                    "feather=\(Self.stableFloatDescription(feather))",
                    "transform=\(transform.fingerprint)",
                    "size=\(size.width)x\(size.height)"
                ]
            )
        case .star(let rect, let points, let innerRadiusRatio, let feather):
            return MaskShapeDescriptor(
                kind: "star",
                fingerprint: fingerprint,
                parameterValues: [
                    "x=\(Self.stableFloatDescription(Float(rect.origin.x)))",
                    "y=\(Self.stableFloatDescription(Float(rect.origin.y)))",
                    "width=\(Self.stableFloatDescription(Float(rect.width)))",
                    "height=\(Self.stableFloatDescription(Float(rect.height)))",
                    "points=\(max(points, 2))",
                    "innerRadiusRatio=\(Self.stableFloatDescription(min(max(innerRadiusRatio, 0), 1)))",
                    "feather=\(Self.stableFloatDescription(feather))",
                    "transform=\(transform.fingerprint)",
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
        switch kind {
        case .rectangle, .ellipse, .roundedRect:
            return try HarbethIO(element: seed, filter: ShapeMask(kind: kind, transform: transform))
                .configured(for: profile)
                .output()
        case .regularPolygon, .star:
            return try HarbethIO(
                element: seed,
                filter: PathMask(recipe: try makePathRecipe(), feather: shapeFeather)
            )
            .configured(for: profile)
            .output()
        }
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0) throws -> MaskDescriptor {
        try makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity,
            pixelFormat: .rgba8Unorm
        )
    }

    public func makeMaskDescriptor(component: MaskComponent = .red,
                                   blendMode: MaskBlendMode = .mix,
                                   invert: Bool = false,
                                   featherPolicy: MaskFeatherPolicy = .none,
                                   opacity: Float = 1.0,
                                   pixelFormat: MTLPixelFormat) throws -> MaskDescriptor {
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
        ShapeMask.stableFloatDescription(value)
    }
}

public extension MaskShapeRecipe {
    static func rectangle(size: C7Size,
                          rect: CGRect,
                          feather: Float = 0,
                          transform: MaskPathTransform = .identity,
                          profile: RenderProfile = .stablePreview) -> MaskShapeRecipe {
        MaskShapeRecipe(
            size: size,
            kind: .rectangle(rect: rect, feather: min(max(feather, 0), 1)),
            transform: transform,
            profile: profile
        )
    }

    static func ellipse(size: C7Size,
                        rect: CGRect,
                        feather: Float = 0,
                        transform: MaskPathTransform = .identity,
                        profile: RenderProfile = .stablePreview) -> MaskShapeRecipe {
        MaskShapeRecipe(
            size: size,
            kind: .ellipse(rect: rect, feather: min(max(feather, 0), 1)),
            transform: transform,
            profile: profile
        )
    }

    static func roundedRect(size: C7Size,
                            rect: CGRect,
                            cornerRadius: Float,
                            feather: Float = 0,
                            transform: MaskPathTransform = .identity,
                            profile: RenderProfile = .stablePreview) -> MaskShapeRecipe {
        let clampedCorner = min(max(cornerRadius, 0), 0.5)
        return MaskShapeRecipe(
            size: size,
            kind: .roundedRect(
                rect: rect,
                cornerRadius: clampedCorner,
                feather: min(max(feather, 0), 1)
            ),
            transform: transform,
            profile: profile
        )
    }

    static func triangle(size: C7Size,
                         rect: CGRect,
                         feather: Float = 0,
                         transform: MaskPathTransform = .identity,
                         profile: RenderProfile = .stablePreview) -> MaskShapeRecipe {
        regularPolygon(
            size: size,
            rect: rect,
            sides: 3,
            feather: feather,
            transform: transform,
            profile: profile
        )
    }

    static func regularPolygon(size: C7Size,
                               rect: CGRect,
                               sides: Int,
                               feather: Float = 0,
                               transform: MaskPathTransform = .identity,
                               profile: RenderProfile = .stablePreview) -> MaskShapeRecipe {
        MaskShapeRecipe(
            size: size,
            kind: .regularPolygon(rect: rect, sides: max(sides, 3), feather: min(max(feather, 0), 1)),
            transform: transform,
            profile: profile
        )
    }

    static func star(size: C7Size,
                     rect: CGRect,
                     points: Int = 5,
                     innerRadiusRatio: Float = 0.44,
                     feather: Float = 0,
                     transform: MaskPathTransform = .identity,
                     profile: RenderProfile = .stablePreview) -> MaskShapeRecipe {
        MaskShapeRecipe(
            size: size,
            kind: .star(
                rect: rect,
                points: max(points, 2),
                innerRadiusRatio: min(max(innerRadiusRatio, 0), 1),
                feather: min(max(feather, 0), 1)
            ),
            transform: transform,
            profile: profile
        )
    }
}

extension MaskShapeRecipe: MaskRebasableRecipe {
    func rebasedRecipe(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> AnyMaskRecipe? {
        AnyMaskRecipe(
            try makePathRecipe().rebased(
                sourceRect: sourceRect,
                logicalSize: logicalSize,
                tileInputSize: tileInputSize
            )
        )
    }

    private func makePathRecipe() throws -> MaskPathRecipe {
        switch kind {
        case .rectangle(let rect, _):
            let points = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY)
            ]
            return MaskPathRecipe(size: size, subpaths: [.polygon(points)], transform: transform, profile: profile)
        case .ellipse(let rect, _):
            return MaskPathRecipe(size: size, subpaths: [Self.ellipseSubpath(rect: rect)], transform: transform, profile: profile)
        case .roundedRect(let rect, let cornerRadius, _):
            return MaskPathRecipe(size: size, subpaths: [Self.roundedRectSubpath(rect: rect, cornerRadius: CGFloat(cornerRadius))], transform: transform, profile: profile)
        case .regularPolygon(let rect, let sides, _):
            return MaskPathRecipe.regularPolygon(
                size: size,
                rect: rect,
                sides: sides,
                transform: transform,
                profile: profile
            )
        case .star(let rect, let points, let innerRadiusRatio, _):
            return MaskPathRecipe.star(
                size: size,
                rect: rect,
                points: points,
                innerRadiusRatio: CGFloat(innerRadiusRatio),
                transform: transform,
                profile: profile
            )
        }
    }

    private var shapeFeather: Float {
        switch kind {
        case .rectangle(_, let feather), .ellipse(_, let feather):
            return min(max(feather, 0), 1)
        case .roundedRect(_, _, let feather):
            return min(max(feather, 0), 1)
        case .regularPolygon(_, _, let feather):
            return min(max(feather, 0), 1)
        case .star(_, _, _, let feather):
            return min(max(feather, 0), 1)
        }
    }

    private static func ellipseSubpath(rect: CGRect) -> MaskPathSubpath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width * 0.5
        let ry = rect.height * 0.5
        let kappa: CGFloat = 0.5522847498307936
        return MaskPathSubpath(commands: [
            .move(to: CGPoint(x: center.x + rx, y: center.y)),
            .cubic(to: CGPoint(x: center.x, y: center.y + ry), control1: CGPoint(x: center.x + rx, y: center.y + ry * kappa), control2: CGPoint(x: center.x + rx * kappa, y: center.y + ry)),
            .cubic(to: CGPoint(x: center.x - rx, y: center.y), control1: CGPoint(x: center.x - rx * kappa, y: center.y + ry), control2: CGPoint(x: center.x - rx, y: center.y + ry * kappa)),
            .cubic(to: CGPoint(x: center.x, y: center.y - ry), control1: CGPoint(x: center.x - rx, y: center.y - ry * kappa), control2: CGPoint(x: center.x - rx * kappa, y: center.y - ry)),
            .cubic(to: CGPoint(x: center.x + rx, y: center.y), control1: CGPoint(x: center.x + rx * kappa, y: center.y - ry), control2: CGPoint(x: center.x + rx, y: center.y - ry * kappa)),
            .close
        ])
    }

    private static func roundedRectSubpath(rect: CGRect, cornerRadius: CGFloat) -> MaskPathSubpath {
        let radius = min(max(cornerRadius, 0), min(rect.width, rect.height) * 0.5)
        let kappa: CGFloat = 0.5522847498307936
        let c = radius * kappa
        return MaskPathSubpath(commands: [
            .move(to: CGPoint(x: rect.minX + radius, y: rect.minY)),
            .line(to: CGPoint(x: rect.maxX - radius, y: rect.minY)),
            .cubic(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control1: CGPoint(x: rect.maxX - radius + c, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY + radius - c)),
            .line(to: CGPoint(x: rect.maxX, y: rect.maxY - radius)),
            .cubic(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.maxY - radius + c), control2: CGPoint(x: rect.maxX - radius + c, y: rect.maxY)),
            .line(to: CGPoint(x: rect.minX + radius, y: rect.maxY)),
            .cubic(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control1: CGPoint(x: rect.minX + radius - c, y: rect.maxY), control2: CGPoint(x: rect.minX, y: rect.maxY - radius + c)),
            .line(to: CGPoint(x: rect.minX, y: rect.minY + radius)),
            .cubic(to: CGPoint(x: rect.minX + radius, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.minY + radius - c), control2: CGPoint(x: rect.minX + radius - c, y: rect.minY)),
            .close
        ])
    }
}

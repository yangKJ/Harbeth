//
//  MaskPrimitives.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreGraphics
import Metal
import simd

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

public enum MaskPathFillRule: String, Sendable, Codable, Equatable, Hashable {
    case nonZero
    case evenOdd
}

public enum MaskPathCommand: Sendable, Codable, Equatable, Hashable {
    case move(to: CGPoint)
    case line(to: CGPoint)
    case quad(to: CGPoint, control: CGPoint)
    case cubic(to: CGPoint, control1: CGPoint, control2: CGPoint)
    case close

    var fingerprint: String {
        switch self {
        case .move(let point):
            return "M\(Self.pointFingerprint(point))"
        case .line(let point):
            return "L\(Self.pointFingerprint(point))"
        case .quad(let point, let control):
            return "Q\(Self.pointFingerprint(control)):\(Self.pointFingerprint(point))"
        case .cubic(let point, let control1, let control2):
            return "C\(Self.pointFingerprint(control1)):\(Self.pointFingerprint(control2)):\(Self.pointFingerprint(point))"
        case .close:
            return "Z"
        }
    }

    static func pointFingerprint(_ point: CGPoint) -> String {
        "\(String(format: "%.4f", point.x)),\(String(format: "%.4f", point.y))"
    }
}

public struct MaskPathSubpath: Sendable, Codable, Equatable, Hashable {
    public var commands: [MaskPathCommand]

    public init(commands: [MaskPathCommand]) {
        self.commands = commands
    }

    public static func polygon(_ points: [CGPoint], closed: Bool = true) -> MaskPathSubpath {
        guard let first = points.first else {
            return MaskPathSubpath(commands: [])
        }
        var commands: [MaskPathCommand] = [.move(to: first)]
        commands.append(contentsOf: points.dropFirst().map { .line(to: $0) })
        if closed {
            commands.append(.close)
        }
        return MaskPathSubpath(commands: commands)
    }

    var fingerprint: String {
        commands.map(\.fingerprint).joined(separator: ";")
    }
}

public struct MaskPathTransform: Sendable, Codable, Equatable, Hashable {
    public var translation: CGPoint
    public var scale: CGPoint
    public var rotationRadians: CGFloat
    public var anchor: CGPoint

    public init(translation: CGPoint = .zero,
                scale: CGPoint = CGPoint(x: 1, y: 1),
                rotationRadians: CGFloat = 0,
                anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.translation = translation
        self.scale = scale
        self.rotationRadians = rotationRadians
        self.anchor = anchor
    }

    public static let identity = MaskPathTransform()

    var fingerprint: String {
        [
            "tx=\(String(format: "%.4f", translation.x))",
            "ty=\(String(format: "%.4f", translation.y))",
            "sx=\(String(format: "%.4f", scale.x))",
            "sy=\(String(format: "%.4f", scale.y))",
            "r=\(String(format: "%.4f", rotationRadians))",
            "ax=\(String(format: "%.4f", anchor.x))",
            "ay=\(String(format: "%.4f", anchor.y))"
        ].joined(separator: ",")
    }

    func applying(to point: CGPoint) -> CGPoint {
        let anchored = CGPoint(x: point.x - anchor.x, y: point.y - anchor.y)
        let scaled = CGPoint(x: anchored.x * scale.x, y: anchored.y * scale.y)
        let cosValue = cos(rotationRadians)
        let sinValue = sin(rotationRadians)
        let rotated = CGPoint(
            x: scaled.x * cosValue - scaled.y * sinValue,
            y: scaled.x * sinValue + scaled.y * cosValue
        )
        return CGPoint(
            x: rotated.x + anchor.x + translation.x,
            y: rotated.y + anchor.y + translation.y
        )
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
            shape: nil,
            path: nil
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
            filter: GradientMask(kind: kind)
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
        GradientMask.stableFloatDescription(value)
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
        return try HarbethIO(element: seed, filter: ShapeMask(kind: kind))
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
        ShapeMask.stableFloatDescription(value)
    }
}

/// 参数化路径遮罩。
///
/// 路径坐标使用归一化画布坐标，输出为普通 coverage texture。
/// `MaskPathRecipe` 是几何蒙版、自由路径、镂空路径和后续矢量 mask 的统一底层表达。
public struct MaskPathRecipe {
    public static let defaultCurveSegments = 12
    public static let maximumEncodedPointCount = 2048

    public var size: C7Size
    public var subpaths: [MaskPathSubpath]
    public var fillRule: MaskPathFillRule
    public var transform: MaskPathTransform
    public var profile: RenderProfile

    public init(size: C7Size,
                subpaths: [MaskPathSubpath],
                fillRule: MaskPathFillRule = .nonZero,
                transform: MaskPathTransform = .identity,
                profile: RenderProfile = .stablePreview) {
        self.size = size
        self.subpaths = subpaths
        self.fillRule = fillRule
        self.transform = transform
        self.profile = profile
    }

    public var fingerprint: String {
        [
            "size=\(size.width)x\(size.height)",
            "fillRule=\(fillRule.rawValue)",
            "transform={\(transform.fingerprint)}",
            "subpaths=\(subpaths.map(\.fingerprint).joined(separator: "||"))",
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
            kind: "maskPathRecipe",
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
            path: pathDescriptor
        )
    }

    public var pathDescriptor: MaskPathDescriptor {
        let encoded = encodedPath()
        return MaskPathDescriptor(
            fillRule: fillRule.rawValue,
            fingerprint: fingerprint,
            pointCount: encoded.points.count,
            subpathCount: encoded.ranges.count,
            parameterValues: [
                "size=\(size.width)x\(size.height)",
                "fillRule=\(fillRule.rawValue)",
                "points=\(encoded.points.count)",
                "subpaths=\(encoded.ranges.count)"
            ]
        )
    }

    public func makeTexture(pixelFormat: MTLPixelFormat = .rgba8Unorm) throws -> MTLTexture {
        let seed = try TextureLoader.makeTexture(
            width: max(size.width, 1),
            height: max(size.height, 1),
            options: [TextureLoader.Option.texturePixelFormat: pixelFormat],
            identifier: "MaskPathRecipe"
        )
        return try HarbethIO(element: seed, filter: PathMask(recipe: self))
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

    public func rebased(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) -> MaskPathRecipe {
        let logicalWidth = max(CGFloat(logicalSize.width), 1)
        let logicalHeight = max(CGFloat(logicalSize.height), 1)
        let tileWidth = max(CGFloat(tileInputSize.width), 1)
        let tileHeight = max(CGFloat(tileInputSize.height), 1)

        func rebase(_ point: CGPoint) -> CGPoint {
            let transformed = transform.applying(to: point)
            let globalPixel = CGPoint(x: transformed.x * logicalWidth, y: transformed.y * logicalHeight)
            let tilePixel = CGPoint(x: globalPixel.x - sourceRect.minX, y: globalPixel.y - sourceRect.minY)
            return CGPoint(x: tilePixel.x / tileWidth, y: tilePixel.y / tileHeight)
        }

        let rebasedSubpaths = subpaths.map { subpath in
            MaskPathSubpath(commands: subpath.commands.map { command in
                switch command {
                case .move(let point):
                    return .move(to: rebase(point))
                case .line(let point):
                    return .line(to: rebase(point))
                case .quad(let point, let control):
                    return .quad(to: rebase(point), control: rebase(control))
                case .cubic(let point, let control1, let control2):
                    return .cubic(to: rebase(point), control1: rebase(control1), control2: rebase(control2))
                case .close:
                    return .close
                }
            })
        }

        return MaskPathRecipe(
            size: tileInputSize,
            subpaths: rebasedSubpaths,
            fillRule: fillRule,
            transform: .identity,
            profile: profile
        )
        .clampedToUnitBounds()
    }

    public func clampedToUnitBounds() -> MaskPathRecipe {
        func clamp(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(point.x, 0), 1),
                y: min(max(point.y, 0), 1)
            )
        }

        let clampedSubpaths = subpaths.map { subpath in
            MaskPathSubpath(commands: subpath.commands.map { command in
                switch command {
                case .move(let point):
                    return .move(to: clamp(point))
                case .line(let point):
                    return .line(to: clamp(point))
                case .quad(let point, let control):
                    return .quad(to: clamp(point), control: clamp(control))
                case .cubic(let point, let control1, let control2):
                    return .cubic(to: clamp(point), control1: clamp(control1), control2: clamp(control2))
                case .close:
                    return .close
                }
            })
        }

        return MaskPathRecipe(
            size: size,
            subpaths: clampedSubpaths,
            fillRule: fillRule,
            transform: transform,
            profile: profile
        )
    }

    func encodedPath(curveSegments: Int = defaultCurveSegments) -> (points: [CGPoint], ranges: [SIMD2<Float>]) {
        func clamp(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(point.x, 0), 1),
                y: min(max(point.y, 0), 1)
            )
        }

        var allPoints: [CGPoint] = []
        var ranges: [SIMD2<Float>] = []
        for subpath in subpaths {
            let flattened = flatten(subpath: subpath, curveSegments: curveSegments)
                .map(transform.applying(to:))
                .map(clamp)
            guard flattened.count >= 3 else { continue }
            let start = allPoints.count
            let allowedCount = min(flattened.count, Self.maximumEncodedPointCount - allPoints.count)
            guard allowedCount >= 3 else { break }
            allPoints.append(contentsOf: flattened.prefix(allowedCount))
            ranges.append(SIMD2<Float>(Float(start), Float(allowedCount)))
            if allPoints.count >= Self.maximumEncodedPointCount {
                break
            }
        }
        return (allPoints, ranges)
    }

    private func flatten(subpath: MaskPathSubpath, curveSegments: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        var current = CGPoint.zero
        var start = CGPoint.zero
        var hasCurrent = false
        for command in subpath.commands {
            switch command {
            case .move(let point):
                current = point
                start = point
                hasCurrent = true
                points.append(point)
            case .line(let point):
                guard hasCurrent else { continue }
                current = point
                points.append(point)
            case .quad(let point, let control):
                guard hasCurrent else { continue }
                for index in 1...max(curveSegments, 1) {
                    let t = CGFloat(index) / CGFloat(max(curveSegments, 1))
                    let oneMinusT = 1 - t
                    points.append(CGPoint(
                        x: oneMinusT * oneMinusT * current.x + 2 * oneMinusT * t * control.x + t * t * point.x,
                        y: oneMinusT * oneMinusT * current.y + 2 * oneMinusT * t * control.y + t * t * point.y
                    ))
                }
                current = point
            case .cubic(let point, let control1, let control2):
                guard hasCurrent else { continue }
                for index in 1...max(curveSegments, 1) {
                    let t = CGFloat(index) / CGFloat(max(curveSegments, 1))
                    let oneMinusT = 1 - t
                    points.append(CGPoint(
                        x: oneMinusT * oneMinusT * oneMinusT * current.x
                            + 3 * oneMinusT * oneMinusT * t * control1.x
                            + 3 * oneMinusT * t * t * control2.x
                            + t * t * t * point.x,
                        y: oneMinusT * oneMinusT * oneMinusT * current.y
                            + 3 * oneMinusT * oneMinusT * t * control1.y
                            + 3 * oneMinusT * t * t * control2.y
                            + t * t * t * point.y
                    ))
                }
                current = point
            case .close:
                guard hasCurrent else { continue }
                if points.last != start {
                    points.append(start)
                }
                current = start
            }
        }
        if let first = points.first, points.last != first {
            points.append(first)
        }
        return points
    }
}

public extension MaskPathRecipe {
    static func rectangle(size: C7Size,
                          rect: CGRect,
                          fillRule: MaskPathFillRule = .nonZero,
                          transform: MaskPathTransform = .identity,
                          profile: RenderProfile = .stablePreview) -> MaskPathRecipe {
        MaskPathRecipe(
            size: size,
            subpaths: [
                .polygon([
                    CGPoint(x: rect.minX, y: rect.minY),
                    CGPoint(x: rect.maxX, y: rect.minY),
                    CGPoint(x: rect.maxX, y: rect.maxY),
                    CGPoint(x: rect.minX, y: rect.maxY)
                ])
            ],
            fillRule: fillRule,
            transform: transform,
            profile: profile
        )
    }

    static func roundedRect(size: C7Size,
                            rect: CGRect,
                            cornerRadius: CGFloat,
                            fillRule: MaskPathFillRule = .nonZero,
                            transform: MaskPathTransform = .identity,
                            profile: RenderProfile = .stablePreview) -> MaskPathRecipe {
        let radius = min(max(cornerRadius, 0), min(rect.width, rect.height) * 0.5)
        let kappa: CGFloat = 0.5522847498307936
        let c = radius * kappa
        let commands: [MaskPathCommand] = [
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
        ]
        return MaskPathRecipe(size: size, subpaths: [MaskPathSubpath(commands: commands)], fillRule: fillRule, transform: transform, profile: profile)
    }

    static func ellipse(size: C7Size,
                        rect: CGRect,
                        fillRule: MaskPathFillRule = .nonZero,
                        transform: MaskPathTransform = .identity,
                        profile: RenderProfile = .stablePreview) -> MaskPathRecipe {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width * 0.5
        let ry = rect.height * 0.5
        let kappa: CGFloat = 0.5522847498307936
        let commands: [MaskPathCommand] = [
            .move(to: CGPoint(x: center.x + rx, y: center.y)),
            .cubic(to: CGPoint(x: center.x, y: center.y + ry), control1: CGPoint(x: center.x + rx, y: center.y + ry * kappa), control2: CGPoint(x: center.x + rx * kappa, y: center.y + ry)),
            .cubic(to: CGPoint(x: center.x - rx, y: center.y), control1: CGPoint(x: center.x - rx * kappa, y: center.y + ry), control2: CGPoint(x: center.x - rx, y: center.y + ry * kappa)),
            .cubic(to: CGPoint(x: center.x, y: center.y - ry), control1: CGPoint(x: center.x - rx, y: center.y - ry * kappa), control2: CGPoint(x: center.x - rx * kappa, y: center.y - ry)),
            .cubic(to: CGPoint(x: center.x + rx, y: center.y), control1: CGPoint(x: center.x + rx * kappa, y: center.y - ry), control2: CGPoint(x: center.x + rx, y: center.y - ry * kappa)),
            .close
        ]
        return MaskPathRecipe(size: size, subpaths: [MaskPathSubpath(commands: commands)], fillRule: fillRule, transform: transform, profile: profile)
    }

    static func regularPolygon(size: C7Size,
                               rect: CGRect,
                               sides: Int,
                               fillRule: MaskPathFillRule = .nonZero,
                               transform: MaskPathTransform = .identity,
                               profile: RenderProfile = .stablePreview) -> MaskPathRecipe {
        let sideCount = max(sides, 3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = (0..<sideCount).map { index in
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * CGFloat.pi / CGFloat(sideCount)
            return CGPoint(x: center.x + cos(angle) * rect.width * 0.5, y: center.y + sin(angle) * rect.height * 0.5)
        }
        return MaskPathRecipe(size: size, subpaths: [.polygon(points)], fillRule: fillRule, transform: transform, profile: profile)
    }

    static func star(size: C7Size,
                     rect: CGRect,
                     points count: Int = 5,
                     innerRadiusRatio: CGFloat = 0.44,
                     fillRule: MaskPathFillRule = .nonZero,
                     transform: MaskPathTransform = .identity,
                     profile: RenderProfile = .stablePreview) -> MaskPathRecipe {
        let vertexCount = max(count, 2) * 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = (0..<vertexCount).map { index in
            let radius = index.isMultiple(of: 2) ? 0.5 : 0.5 * innerRadiusRatio
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * CGFloat.pi / CGFloat(vertexCount)
            return CGPoint(x: center.x + cos(angle) * rect.width * radius, y: center.y + sin(angle) * rect.height * radius)
        }
        return MaskPathRecipe(size: size, subpaths: [.polygon(points)], fillRule: fillRule, transform: transform, profile: profile)
    }

    static func heart(size: C7Size,
                      rect: CGRect,
                      fillRule: MaskPathFillRule = .nonZero,
                      transform: MaskPathTransform = .identity,
                      profile: RenderProfile = .stablePreview) -> MaskPathRecipe {
        let points = (0..<96).map { index -> CGPoint in
            let t = CGFloat(index) / 96 * 2 * CGFloat.pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return CGPoint(
                x: rect.midX + (x / 34) * rect.width,
                y: rect.midY - (y / 34) * rect.height
            )
        }
        return MaskPathRecipe(size: size, subpaths: [.polygon(points)], fillRule: fillRule, transform: transform, profile: profile)
    }
}

public struct LocalEffectRecipe {
    public var filters: [C7FilterProtocol]
    public var mask: MaskDescriptor
    public var maskRecipe: MaskCompositeRecipe?
    public var maskGraphOverride: MaskGraphDescriptor?
    public var foregroundBlendType: C7Blend.BlendType?
    public var foregroundBlendOpacity: Float

    public init(filters: [C7FilterProtocol], mask: MaskDescriptor, foregroundBlendType: C7Blend.BlendType? = nil, foregroundBlendOpacity: Float = 1.0) {
        self.filters = filters
        self.mask = mask
        self.maskRecipe = nil
        self.maskGraphOverride = nil
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
    }

    public init(filters: [C7FilterProtocol], maskRecipe: MaskCompositeRecipe, foregroundBlendType: C7Blend.BlendType? = nil, foregroundBlendOpacity: Float = 1.0) {
        self.filters = filters
        self.mask = maskRecipe.baseMask
        self.maskRecipe = maskRecipe
        self.maskGraphOverride = nil
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
    }

    public init(filters: [C7FilterProtocol],
                maskGradientRecipe: MaskGradientRecipe,
                component: MaskComponent = .red,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0,
                foregroundBlendType: C7Blend.BlendType? = nil,
                foregroundBlendOpacity: Float = 1.0) throws {
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
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
    }

    public init(filters: [C7FilterProtocol],
                maskShapeRecipe: MaskShapeRecipe,
                component: MaskComponent = .red,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0,
                foregroundBlendType: C7Blend.BlendType? = nil,
                foregroundBlendOpacity: Float = 1.0) throws {
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
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
    }

    public init(filters: [C7FilterProtocol],
                maskPathRecipe: MaskPathRecipe,
                component: MaskComponent = .red,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0,
                foregroundBlendType: C7Blend.BlendType? = nil,
                foregroundBlendOpacity: Float = 1.0) throws {
        self.filters = filters
        self.mask = try maskPathRecipe.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.maskRecipe = nil
        self.maskGraphOverride = maskPathRecipe.graphDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.foregroundBlendType = foregroundBlendType
        self.foregroundBlendOpacity = min(max(foregroundBlendOpacity, 0), 1)
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
            mask: (maskGraphOverride ?? maskRecipe?.graphDescriptor) ?? mask.graphDescriptor,
            foregroundBlendMode: foregroundBlendType.map(String.init(describing:)),
            foregroundBlendOpacity: foregroundBlendOpacity
        )
    }
}

public struct MaskCompositeStep {
    public var name: String
    public var mask: MaskDescriptor
    public var gradientDescriptor: MaskGradientDescriptor?
    public var shapeDescriptor: MaskShapeDescriptor?
    public var pathDescriptor: MaskPathDescriptor?
    public var gradientRecipe: MaskGradientRecipe?
    public var shapeRecipe: MaskShapeRecipe?
    public var pathRecipe: MaskPathRecipe?

    public init(name: String = "mask",
                mask: MaskDescriptor,
                gradientDescriptor: MaskGradientDescriptor? = nil,
                shapeDescriptor: MaskShapeDescriptor? = nil,
                pathDescriptor: MaskPathDescriptor? = nil,
                gradientRecipe: MaskGradientRecipe? = nil,
                shapeRecipe: MaskShapeRecipe? = nil,
                pathRecipe: MaskPathRecipe? = nil) {
        self.name = name
        self.mask = mask
        self.gradientDescriptor = gradientDescriptor
        self.shapeDescriptor = shapeDescriptor
        self.pathDescriptor = pathDescriptor
        self.gradientRecipe = gradientRecipe
        self.shapeRecipe = shapeRecipe
        self.pathRecipe = pathRecipe
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
        if let pathDescriptor {
            parts.append("path=\(pathDescriptor.fingerprint)")
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
            shape: shapeDescriptor,
            path: pathDescriptor
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

    public static func exclude(_ mask: MaskDescriptor, name: String = "exclude") -> MaskCompositeStep {
        var descriptor = mask
        descriptor.blendMode = .exclude
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
            gradientDescriptor: maskGradientRecipe.gradientDescriptor,
            gradientRecipe: maskGradientRecipe
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
            gradientDescriptor: maskGradientRecipe.gradientDescriptor,
            gradientRecipe: maskGradientRecipe
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
            gradientDescriptor: maskGradientRecipe.gradientDescriptor,
            gradientRecipe: maskGradientRecipe
        )
    }

    public static func exclude(_ maskGradientRecipe: MaskGradientRecipe,
                               component: MaskComponent = .red,
                               invert: Bool = false,
                               featherPolicy: MaskFeatherPolicy = .none,
                               opacity: Float = 1.0,
                               name: String = "exclude") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskGradientRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .exclude,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            gradientDescriptor: maskGradientRecipe.gradientDescriptor,
            gradientRecipe: maskGradientRecipe
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
            shapeDescriptor: maskShapeRecipe.shapeDescriptor,
            shapeRecipe: maskShapeRecipe
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
            shapeDescriptor: maskShapeRecipe.shapeDescriptor,
            shapeRecipe: maskShapeRecipe
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
            shapeDescriptor: maskShapeRecipe.shapeDescriptor,
            shapeRecipe: maskShapeRecipe
        )
    }

    public static func exclude(_ maskShapeRecipe: MaskShapeRecipe,
                               component: MaskComponent = .red,
                               invert: Bool = false,
                               featherPolicy: MaskFeatherPolicy = .none,
                               opacity: Float = 1.0,
                               name: String = "exclude") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskShapeRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .exclude,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            shapeDescriptor: maskShapeRecipe.shapeDescriptor,
            shapeRecipe: maskShapeRecipe
        )
    }

    public static func add(_ maskPathRecipe: MaskPathRecipe,
                           component: MaskComponent = .red,
                           invert: Bool = false,
                           featherPolicy: MaskFeatherPolicy = .none,
                           opacity: Float = 1.0,
                           name: String = "add") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskPathRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .add,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            pathDescriptor: maskPathRecipe.pathDescriptor,
            pathRecipe: maskPathRecipe
        )
    }

    public static func intersect(_ maskPathRecipe: MaskPathRecipe,
                                 component: MaskComponent = .red,
                                 invert: Bool = false,
                                 featherPolicy: MaskFeatherPolicy = .none,
                                 opacity: Float = 1.0,
                                 name: String = "intersect") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskPathRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .multiply,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            pathDescriptor: maskPathRecipe.pathDescriptor,
            pathRecipe: maskPathRecipe
        )
    }

    public static func subtract(_ maskPathRecipe: MaskPathRecipe,
                                component: MaskComponent = .red,
                                invert: Bool = false,
                                featherPolicy: MaskFeatherPolicy = .none,
                                opacity: Float = 1.0,
                                name: String = "subtract") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskPathRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .subtract,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            pathDescriptor: maskPathRecipe.pathDescriptor,
            pathRecipe: maskPathRecipe
        )
    }

    public static func exclude(_ maskPathRecipe: MaskPathRecipe,
                               component: MaskComponent = .red,
                               invert: Bool = false,
                               featherPolicy: MaskFeatherPolicy = .none,
                               opacity: Float = 1.0,
                               name: String = "exclude") throws -> MaskCompositeStep {
        MaskCompositeStep(
            name: name,
            mask: try maskPathRecipe.makeMaskDescriptor(
                component: component,
                blendMode: .exclude,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity
            ),
            pathDescriptor: maskPathRecipe.pathDescriptor,
            pathRecipe: maskPathRecipe
        )
    }
}

public struct MaskCompositeRecipe {
    public var baseMask: MaskDescriptor
    public var baseGraphOverride: MaskGraphDescriptor?
    public var baseGradientRecipe: MaskGradientRecipe?
    public var baseShapeRecipe: MaskShapeRecipe?
    public var basePathRecipe: MaskPathRecipe?
    public var steps: [MaskCompositeStep]
    public var profile: RenderProfile

    public init(baseMask: MaskDescriptor, masks: [MaskDescriptor] = [], profile: RenderProfile = .stablePreview) {
        self.baseMask = baseMask
        self.baseGraphOverride = nil
        self.baseGradientRecipe = nil
        self.baseShapeRecipe = nil
        self.basePathRecipe = nil
        self.steps = masks.enumerated().map { index, mask in
            MaskCompositeStep(name: "mask\(index)", mask: mask)
        }
        self.profile = profile
    }

    public init(baseMask: MaskDescriptor, steps: [MaskCompositeStep], profile: RenderProfile = .stablePreview) {
        self.baseMask = baseMask
        self.baseGraphOverride = nil
        self.baseGradientRecipe = nil
        self.baseShapeRecipe = nil
        self.basePathRecipe = nil
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
        self.baseGradientRecipe = baseGradientRecipe
        self.baseShapeRecipe = nil
        self.basePathRecipe = nil
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
        self.baseGradientRecipe = nil
        self.baseShapeRecipe = baseShapeRecipe
        self.basePathRecipe = nil
        self.steps = steps
        self.profile = baseShapeRecipe.profile
    }

    public init(basePathRecipe: MaskPathRecipe,
                component: MaskComponent = .red,
                blendMode: MaskBlendMode = .mix,
                invert: Bool = false,
                featherPolicy: MaskFeatherPolicy = .none,
                opacity: Float = 1.0,
                steps: [MaskCompositeStep] = []) throws {
        self.baseMask = try basePathRecipe.makeMaskDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.baseGraphOverride = basePathRecipe.graphDescriptor(
            component: component,
            blendMode: blendMode,
            invert: invert,
            featherPolicy: featherPolicy,
            opacity: opacity
        )
        self.baseGradientRecipe = nil
        self.baseShapeRecipe = nil
        self.basePathRecipe = basePathRecipe
        self.steps = steps
        self.profile = basePathRecipe.profile
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

    public func excluding(_ mask: MaskDescriptor, name: String = "exclude") -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(.exclude(mask, name: name))
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

    public func excluding(_ maskGradientRecipe: MaskGradientRecipe,
                          component: MaskComponent = .red,
                          invert: Bool = false,
                          featherPolicy: MaskFeatherPolicy = .none,
                          opacity: Float = 1.0,
                          name: String = "exclude") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .exclude(
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

    public func excluding(_ maskShapeRecipe: MaskShapeRecipe,
                          component: MaskComponent = .red,
                          invert: Bool = false,
                          featherPolicy: MaskFeatherPolicy = .none,
                          opacity: Float = 1.0,
                          name: String = "exclude") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .exclude(
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

    public func adding(_ maskPathRecipe: MaskPathRecipe,
                       component: MaskComponent = .red,
                       invert: Bool = false,
                       featherPolicy: MaskFeatherPolicy = .none,
                       opacity: Float = 1.0,
                       name: String = "add") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .add(
                maskPathRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func intersecting(_ maskPathRecipe: MaskPathRecipe,
                             component: MaskComponent = .red,
                             invert: Bool = false,
                             featherPolicy: MaskFeatherPolicy = .none,
                             opacity: Float = 1.0,
                             name: String = "intersect") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .intersect(
                maskPathRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func subtracting(_ maskPathRecipe: MaskPathRecipe,
                            component: MaskComponent = .red,
                            invert: Bool = false,
                            featherPolicy: MaskFeatherPolicy = .none,
                            opacity: Float = 1.0,
                            name: String = "subtract") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .subtract(
                maskPathRecipe,
                component: component,
                invert: invert,
                featherPolicy: featherPolicy,
                opacity: opacity,
                name: name
            )
        )
        return copy
    }

    public func excluding(_ maskPathRecipe: MaskPathRecipe,
                          component: MaskComponent = .red,
                          invert: Bool = false,
                          featherPolicy: MaskFeatherPolicy = .none,
                          opacity: Float = 1.0,
                          name: String = "exclude") throws -> MaskCompositeRecipe {
        var copy = self
        copy.steps.append(
            try .exclude(
                maskPathRecipe,
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
            shape: baseGraphOverride?.shape,
            path: baseGraphOverride?.path
        )
    }

    public func makeTexture() throws -> MTLTexture {
        var current = try HarbethIO(
            element: baseMask.texture,
            filter: MaskCoverageExtract(mask: baseMask)
        )
        .configured(for: profile)
        .output()

        for step in steps {
            current = try HarbethIO(
                element: current,
                filter: MaskCoverageBlend(baseComponent: .red, mask: step.mask)
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

    public func rebased(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> MaskCompositeRecipe? {
        func rebaseStep(_ step: MaskCompositeStep) throws -> MaskCompositeStep? {
            if let pathRecipe = step.pathRecipe {
                let rebasedPath = pathRecipe.rebased(
                    sourceRect: sourceRect,
                    logicalSize: logicalSize,
                    tileInputSize: tileInputSize
                )
                switch step.mask.blendMode {
                case .add:
                    return try .add(
                        rebasedPath,
                        component: step.mask.component,
                        invert: step.mask.invert,
                        featherPolicy: step.mask.featherPolicy,
                        opacity: step.mask.opacity,
                        name: step.name
                    )
                case .multiply:
                    return try .intersect(
                        rebasedPath,
                        component: step.mask.component,
                        invert: step.mask.invert,
                        featherPolicy: step.mask.featherPolicy,
                        opacity: step.mask.opacity,
                        name: step.name
                    )
                case .subtract:
                    return try .subtract(
                        rebasedPath,
                        component: step.mask.component,
                        invert: step.mask.invert,
                        featherPolicy: step.mask.featherPolicy,
                        opacity: step.mask.opacity,
                        name: step.name
                    )
                case .exclude:
                    return try .exclude(
                        rebasedPath,
                        component: step.mask.component,
                        invert: step.mask.invert,
                        featherPolicy: step.mask.featherPolicy,
                        opacity: step.mask.opacity,
                        name: step.name
                    )
                case .mix, .replace:
                    return nil
                }
            }
            return nil
        }

        if let basePathRecipe {
            let rebasedBase = basePathRecipe.rebased(
                sourceRect: sourceRect,
                logicalSize: logicalSize,
                tileInputSize: tileInputSize
            )
            var rebasedRecipe = try MaskCompositeRecipe(
                basePathRecipe: rebasedBase,
                component: baseMask.component,
                blendMode: baseMask.blendMode,
                invert: baseMask.invert,
                featherPolicy: baseMask.featherPolicy,
                opacity: baseMask.opacity,
                steps: []
            )
            for step in steps {
                guard let rebasedStep = try rebaseStep(step) else {
                    return nil
                }
                rebasedRecipe.steps.append(rebasedStep)
            }
            return rebasedRecipe
        }

        return nil
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
            shape: nil,
            path: nil
        )
    }
}

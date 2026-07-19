//
//  MaskPathRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation
import CoreGraphics
import Metal
import simd

/// 参数化向量路径遮罩。
///
/// 路径坐标使用归一化画布坐标，输出为普通 coverage texture。
/// `MaskPathRecipe` 负责 custom subpaths、自由路径、镂空路径和装饰性向量轮廓。
public struct MaskPathRecipe {
    public static let defaultCurveSegments = 12
    public static let maximumEncodedPointCount = 2048

    public var size: C7Size
    public var subpaths: [MaskPathSubpath]
    public var fillRule: MaskPathFillRule
    public var transform: MaskPathTransform
    public var feather: Float
    public var profile: RenderProfile

    public init(size: C7Size,
                subpaths: [MaskPathSubpath],
                fillRule: MaskPathFillRule = .nonZero,
                transform: MaskPathTransform = .identity,
                feather: Float = 0,
                profile: RenderProfile = .stablePreview) {
        self.init(
            size: size,
            subpaths: subpaths,
            fillRule: fillRule,
            transform: transform,
            feather: feather,
            profile: profile,
            allowsExtendedFeather: false
        )
    }

    private init(size: C7Size,
                 subpaths: [MaskPathSubpath],
                 fillRule: MaskPathFillRule,
                 transform: MaskPathTransform,
                 feather: Float,
                 profile: RenderProfile,
                 allowsExtendedFeather: Bool) {
        self.size = size
        self.subpaths = subpaths
        self.fillRule = fillRule
        self.transform = transform
        self.feather = allowsExtendedFeather ? max(feather, 0) : min(max(feather, 0), 1)
        self.profile = profile
    }

    public var fingerprint: String {
        [
            "size=\(size.width)x\(size.height)",
            "fillRule=\(fillRule.rawValue)",
            "transform={\(transform.fingerprint)}",
            "feather=\(Self.stableFloatDescription(feather))",
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
                "feather=\(Self.stableFloatDescription(feather))",
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
        return try HarbethIO(element: seed, filter: PathMask(recipe: self, feather: feather))
            .configured(for: profile)
            .output()
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

    public func rebased(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) -> MaskPathRecipe {
        let logicalWidth = max(CGFloat(logicalSize.width), 1)
        let logicalHeight = max(CGFloat(logicalSize.height), 1)
        let tileWidth = max(CGFloat(tileInputSize.width), 1)
        let tileHeight = max(CGFloat(tileInputSize.height), 1)
        let logicalShortEdge = max(min(logicalWidth, logicalHeight), 1)
        let tileShortEdge = max(min(tileWidth, tileHeight), 1)
        let rebasedFeather = max(feather * Float(logicalShortEdge / tileShortEdge), 0)

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
            feather: rebasedFeather,
            profile: profile,
            allowsExtendedFeather: true
        )
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
            feather: feather,
            profile: profile,
            allowsExtendedFeather: true
        )
    }

    func rebasedSource(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> AnyMaskRecipe? {
        AnyMaskRecipe(
            rebased(
                sourceRect: sourceRect,
                logicalSize: logicalSize,
                tileInputSize: tileInputSize
            )
        )
    }

    func encodedPath(curveSegments: Int = defaultCurveSegments) -> (points: [CGPoint], ranges: [SIMD2<Float>]) {
        var allPoints: [CGPoint] = []
        var ranges: [SIMD2<Float>] = []
        for subpath in subpaths {
            let flattened = flatten(subpath: subpath, curveSegments: curveSegments)
                .map(transform.applying(to:))
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

    private static func stableFloatDescription(_ value: Float) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

public extension MaskPathRecipe {
    static func regularPolygon(size: C7Size,
                               rect: CGRect,
                               sides: Int,
                               fillRule: MaskPathFillRule = .nonZero,
                               transform: MaskPathTransform = .identity,
                               feather: Float = 0,
                               profile: RenderProfile = .stablePreview) -> MaskPathRecipe {
        let sideCount = max(sides, 3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = (0..<sideCount).map { index in
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * CGFloat.pi / CGFloat(sideCount)
            return CGPoint(x: center.x + cos(angle) * rect.width * 0.5, y: center.y + sin(angle) * rect.height * 0.5)
        }
        return MaskPathRecipe(size: size, subpaths: [.polygon(points)], fillRule: fillRule, transform: transform, feather: feather, profile: profile)
    }

    static func star(size: C7Size,
                     rect: CGRect,
                     points count: Int = 5,
                     innerRadiusRatio: CGFloat = 0.44,
                     fillRule: MaskPathFillRule = .nonZero,
                     transform: MaskPathTransform = .identity,
                     feather: Float = 0,
                     profile: RenderProfile = .stablePreview) -> MaskPathRecipe {
        let vertexCount = max(count, 2) * 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = (0..<vertexCount).map { index in
            let radius = index.isMultiple(of: 2) ? 0.5 : 0.5 * innerRadiusRatio
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * CGFloat.pi / CGFloat(vertexCount)
            return CGPoint(x: center.x + cos(angle) * rect.width * radius, y: center.y + sin(angle) * rect.height * radius)
        }
        return MaskPathRecipe(size: size, subpaths: [.polygon(points)], fillRule: fillRule, transform: transform, feather: feather, profile: profile)
    }

    static func heart(size: C7Size,
                      rect: CGRect,
                      fillRule: MaskPathFillRule = .nonZero,
                      transform: MaskPathTransform = .identity,
                      feather: Float = 0,
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
        return MaskPathRecipe(size: size, subpaths: [.polygon(points)], fillRule: fillRule, transform: transform, feather: feather, profile: profile)
    }
}

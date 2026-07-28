//
//  MaskBrushRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/19.
//

import Foundation
import Metal

public enum MaskStorageFormat: String, Sendable, Codable, Equatable, Hashable {
    case coverage8
    case coverage16Float
    case rgba8
    case rgba16Float

    public var pixelFormat: MTLPixelFormat {
        switch self {
        case .coverage8: return .r8Unorm
        case .coverage16Float: return .r16Float
        case .rgba8: return .rgba8Unorm
        case .rgba16Float: return .rgba16Float
        }
    }
}

public enum MaskBrushMode: String, Sendable, Codable, Equatable, Hashable {
    case paint
    case erase

    public var recommendedBlendMode: MaskBlendMode {
        switch self {
        case .paint: return .add
        case .erase: return .subtract
        }
    }
}

public struct MaskBrushPoint: Sendable, Codable, Equatable, Hashable {
    public let point: CGPoint
    public let pressure: Float

    public init(point: CGPoint, pressure: Float = 1) {
        self.point = CGPoint(
            x: Self.finite(point.x),
            y: Self.finite(point.y)
        )
        self.pressure = Self.clampUnit(pressure)
    }

    private static func finite(_ value: CGFloat) -> CGFloat {
        value.isFinite ? value : 0
    }

    private static func clampUnit(_ value: Float) -> Float {
        guard value.isFinite else { return 1 }
        return min(max(value, 0.05), 1)
    }
}

public struct MaskBrushSettings: Sendable, Codable, Equatable, Hashable {
    public let width: Float
    public let hardness: Float
    public let spacing: Float
    public let smoothing: Float
    public let flow: Float
    public let density: Float
    public let mode: MaskBrushMode

    public init(width: Float = 0.08,
                hardness: Float = 0.72,
                spacing: Float = 0.18,
                smoothing: Float = 0.45,
                flow: Float = 1,
                density: Float = 1,
                mode: MaskBrushMode = .paint) {
        self.width = Self.clamp(width, lower: 0.002, upper: 1)
        self.hardness = Self.clamp(hardness, lower: 0, upper: 1)
        self.spacing = Self.clamp(spacing, lower: 0.02, upper: 1)
        self.smoothing = Self.clamp(smoothing, lower: 0, upper: 1)
        self.flow = Self.clamp(flow, lower: 0, upper: 1)
        self.density = Self.clamp(density, lower: 0, upper: 1)
        self.mode = mode
    }

    private static func clamp(_ value: Float, lower: Float, upper: Float) -> Float {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }
}

/// Open-centerline brush mask with pressure-aware width and deterministic smoothing.
public struct MaskBrushRecipe {
    public static let maximumPreparedPointCount = 512

    public var size: C7Size
    public var points: [MaskBrushPoint]
    public var settings: MaskBrushSettings
    public var profile: RenderProfile
    public var storageFormat: MaskStorageFormat
    private let pointsArePrepared: Bool

    public init(size: C7Size,
                points: [MaskBrushPoint],
                settings: MaskBrushSettings = MaskBrushSettings(),
                profile: RenderProfile = .stablePreview,
                storageFormat: MaskStorageFormat = .coverage8) {
        self.size = size
        self.points = points
        self.settings = settings
        self.profile = profile
        self.storageFormat = storageFormat
        self.pointsArePrepared = false
    }

    /// 使用已经在完整逻辑画布中平滑、重采样过的中心线。大图 tile 只应重基这些点，
    /// 不能在每个 tile 内再次改变曲线或采样密度。
    public init(size: C7Size,
                preparedPoints: [MaskBrushPoint],
                settings: MaskBrushSettings = MaskBrushSettings(),
                profile: RenderProfile = .stablePreview,
                storageFormat: MaskStorageFormat = .coverage8) {
        self.size = size
        self.points = Self.boundedPreparedPoints(preparedPoints)
        self.settings = settings
        self.profile = profile
        self.storageFormat = storageFormat
        self.pointsArePrepared = true
    }

    public var preparedPoints: [MaskBrushPoint] {
        pointsArePrepared ? points : Self.prepare(
            points: points,
            settings: settings,
            maximumPointCount: Self.maximumPreparedPointCount
        )
    }

    public var fingerprint: String {
        let pointsValue = preparedPoints.map {
            "\(Self.stable(Double($0.point.x))),\(Self.stable(Double($0.point.y))),\(Self.stable(Double($0.pressure)))"
        }.joined(separator: ";")
        return [
            "size=\(size.width)x\(size.height)",
            "points=\(pointsValue)",
            "width=\(Self.stable(Double(settings.width)))",
            "hardness=\(Self.stable(Double(settings.hardness)))",
            "spacing=\(Self.stable(Double(settings.spacing)))",
            "smoothing=\(Self.stable(Double(settings.smoothing)))",
            "flow=\(Self.stable(Double(settings.flow)))",
            "density=\(Self.stable(Double(settings.density)))",
            "mode=\(settings.mode.rawValue)",
            "storage=\(storageFormat.rawValue)",
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
                                opacity: Float = 1) -> MaskGraphDescriptor {
        MaskGraphDescriptor(
            kind: "maskBrushRecipe",
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
        let seed = try TextureLoader.makeTexture(
            width: max(size.width, 1),
            height: max(size.height, 1),
            options: [.texturePixelFormat: storageFormat.pixelFormat],
            identifier: "MaskBrushRecipe"
        )
        return try HarbethIO(element: seed, filter: BrushMask(points: preparedPoints, settings: settings))
            .configured(for: profile)
            .output()
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

extension MaskBrushRecipe {
    static func prepareIncremental(points: [MaskBrushPoint], settings: MaskBrushSettings) -> [MaskBrushPoint] {
        prepare(points: points, settings: settings, maximumPointCount: nil)
    }

    private static func prepare(points: [MaskBrushPoint],
                                settings: MaskBrushSettings,
                                maximumPointCount: Int?) -> [MaskBrushPoint] {
        guard points.count > 1 else { return points }
        let smoothingPasses = Int((settings.smoothing * 3).rounded())
        var result = points
        for _ in 0..<smoothingPasses {
            var next = [result[0]]
            for index in 1..<(result.count - 1) {
                let previous = result[index - 1]
                let current = result[index]
                let following = result[index + 1]
                next.append(MaskBrushPoint(
                    point: CGPoint(
                        x: previous.point.x * 0.25 + current.point.x * 0.5 + following.point.x * 0.25,
                        y: previous.point.y * 0.25 + current.point.y * 0.5 + following.point.y * 0.25
                    ),
                    pressure: previous.pressure * 0.25 + current.pressure * 0.5 + following.pressure * 0.25
                ))
            }
            next.append(result[result.count - 1])
            result = next
        }
        return resample(
            result,
            distance: CGFloat(settings.width * settings.spacing),
            maximumPointCount: maximumPointCount
        )
    }

    /// 以笔刷直径的比例均匀采样中心线，避免输入事件频率改变笔触密度和边缘连续性。
    private static func resample(_ points: [MaskBrushPoint],
                                 distance: CGFloat,
                                 maximumPointCount: Int?) -> [MaskBrushPoint] {
        guard points.count > 1 else { return points }
        let totalLength = zip(points, points.dropFirst()).reduce(CGFloat.zero) { result, pair in
            result + hypot(pair.1.point.x - pair.0.point.x, pair.1.point.y - pair.0.point.y)
        }
        let maximumSegmentCount = maximumPointCount.map { CGFloat(max($0 - 2, 1)) }
        let targetDistance = max(distance, 0.0005, maximumSegmentCount.map { totalLength / $0 } ?? 0)
        var result = [points[0]]
        var carry: CGFloat = 0

        for index in 1..<points.count {
            var start = points[index - 1]
            let end = points[index]
            var segmentLength = hypot(end.point.x - start.point.x, end.point.y - start.point.y)
            guard segmentLength > 0 else { continue }

            while carry + segmentLength >= targetDistance,
                  maximumPointCount.map({ result.count < $0 - 1 }) ?? true {
                let fraction = (targetDistance - carry) / segmentLength
                let point = MaskBrushPoint(
                    point: CGPoint(
                        x: start.point.x + (end.point.x - start.point.x) * fraction,
                        y: start.point.y + (end.point.y - start.point.y) * fraction
                    ),
                    pressure: start.pressure + (end.pressure - start.pressure) * Float(fraction)
                )
                result.append(point)
                start = point
                segmentLength = hypot(end.point.x - start.point.x, end.point.y - start.point.y)
                carry = 0
            }
            carry += segmentLength
        }

        if result.last != points.last, maximumPointCount.map({ result.count < $0 }) ?? true {
            result.append(points[points.count - 1])
        }
        return result
    }

    static func boundedPreparedPoints(_ points: [MaskBrushPoint]) -> [MaskBrushPoint] {
        guard points.count > maximumPreparedPointCount else { return points }
        let scale = Double(points.count - 1) / Double(maximumPreparedPointCount - 1)
        return (0..<maximumPreparedPointCount).map { index in
            points[Int((Double(index) * scale).rounded())]
        }
    }

    static func stable(_ value: Double) -> String {
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

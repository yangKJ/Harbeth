//
//  MaskPaths.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation

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
    case roundedRect(rect: CGRect, cornerRadius: Float = 0, feather: Float = 0)
    case regularPolygon(rect: CGRect, sides: Int, feather: Float = 0)
    case star(rect: CGRect, points: Int = 5, innerRadiusRatio: Float = 0.44, feather: Float = 0)

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
        case .roundedRect(let rect, let cornerRadius, let feather):
            return [
                "kind=roundedRect",
                "rect=\(String(format: "%.4f", rect.origin.x)),\(String(format: "%.4f", rect.origin.y)),\(String(format: "%.4f", rect.width)),\(String(format: "%.4f", rect.height))",
                "cornerRadius=\(String(format: "%.4f", min(max(cornerRadius, 0), 1)))",
                "feather=\(String(format: "%.4f", min(max(feather, 0), 1)))"
            ].joined(separator: "|")
        case .regularPolygon(let rect, let sides, let feather):
            return [
                "kind=regularPolygon",
                "rect=\(String(format: "%.4f", rect.origin.x)),\(String(format: "%.4f", rect.origin.y)),\(String(format: "%.4f", rect.width)),\(String(format: "%.4f", rect.height))",
                "sides=\(max(sides, 3))",
                "feather=\(String(format: "%.4f", min(max(feather, 0), 1)))"
            ].joined(separator: "|")
        case .star(let rect, let points, let innerRadiusRatio, let feather):
            return [
                "kind=star",
                "rect=\(String(format: "%.4f", rect.origin.x)),\(String(format: "%.4f", rect.origin.y)),\(String(format: "%.4f", rect.width)),\(String(format: "%.4f", rect.height))",
                "points=\(max(points, 2))",
                "innerRadiusRatio=\(String(format: "%.4f", min(max(innerRadiusRatio, 0), 1)))",
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
    /// 旋转所在画布的像素宽高比。默认 1 保留归一化坐标空间的既有语义。
    public var rotationAspectRatio: CGFloat

    public init(translation: CGPoint = .zero,
                scale: CGPoint = CGPoint(x: 1, y: 1),
                rotationRadians: CGFloat = 0,
                anchor: CGPoint = CGPoint(x: 0.5, y: 0.5),
                rotationAspectRatio: CGFloat = 1) {
        self.translation = translation
        self.scale = scale
        self.rotationRadians = rotationRadians
        self.anchor = anchor
        self.rotationAspectRatio = max(rotationAspectRatio, 0.000001)
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
            "ay=\(String(format: "%.4f", anchor.y))",
            "rotationAspect=\(String(format: "%.4f", rotationAspectRatio))"
        ].joined(separator: ",")
    }

    func applying(to point: CGPoint) -> CGPoint {
        let anchored = CGPoint(x: point.x - anchor.x, y: point.y - anchor.y)
        let scaled = CGPoint(x: anchored.x * scale.x, y: anchored.y * scale.y)
        let cosValue = cos(rotationRadians)
        let sinValue = sin(rotationRadians)
        let aspect = max(rotationAspectRatio, 0.000001)
        let rotated = CGPoint(
            x: (scaled.x * aspect * cosValue - scaled.y * sinValue) / aspect,
            y: scaled.x * aspect * sinValue + scaled.y * cosValue
        )
        return CGPoint(
            x: rotated.x + anchor.x + translation.x,
            y: rotated.y + anchor.y + translation.y
        )
    }
}

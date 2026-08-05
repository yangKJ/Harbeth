//
//  RenderVectorMask.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import CoreGraphics
import Foundation

/// 通过 GPU rasterization 生成简单闭合多边形 coverage mask。
///
/// 坐标使用左上角为原点的归一化画布空间。凹多边形会在 CPU 侧稳定三角化；
/// 自相交路径、多 subpath、even-odd 镂空和 feather 继续使用 `MaskPathRecipe`。
public struct RenderVectorMask: RenderProtocol {

    public enum ValidationError: Error, Equatable, Sendable {
        case insufficientPoints
        case tooManyPoints
        case nonFinitePoint(index: Int)
        case degeneratePolygon
        case nonSimplePolygon
        case unsupportedSampleCount(Int)
    }

    public static let maximumPointCount = 4096

    public let points: [FreePoint2D]
    public let rasterSampleCount: Int
    private let triangleVertices: [FreePoint2D]

    public var modifier: ModifierEnum {
        .render(vertex: "renderVectorMaskVertex", fragment: "renderVectorMaskFragment")
    }

    public var renderPrimitiveTopology: RenderPrimitiveTopology { .triangle }
    public var renderRasterSampleCount: Int { rasterSampleCount }
    public var renderSamplerConsumption: RenderSamplerConsumption { .shaderDefined }
    public var renderOutputContract: RenderOutputContract {
        RenderOutputContract(alpha: .premultiplied)
    }

    public init(points: [FreePoint2D], rasterSampleCount: Int = 4) throws {
        var normalizedPoints = points
        if normalizedPoints.count > 1, normalizedPoints.first == normalizedPoints.last {
            normalizedPoints.removeLast()
        }
        guard normalizedPoints.count >= 3 else {
            throw ValidationError.insufficientPoints
        }
        guard normalizedPoints.count <= Self.maximumPointCount else {
            throw ValidationError.tooManyPoints
        }
        if let index = normalizedPoints.firstIndex(where: { !$0.x.isFinite || !$0.y.isFinite }) {
            throw ValidationError.nonFinitePoint(index: index)
        }
        guard [1, 2, 4, 8].contains(rasterSampleCount) else {
            throw ValidationError.unsupportedSampleCount(rasterSampleCount)
        }
        let triangles = try Self.triangulate(normalizedPoints)
        self.points = normalizedPoints
        self.rasterSampleCount = rasterSampleCount
        self.triangleVertices = triangles
    }

    public init(points: [CGPoint], rasterSampleCount: Int = 4) throws {
        try self.init(
            points: points.map { FreePoint2D(x: Float($0.x), y: Float($0.y)) },
            rasterSampleCount: rasterSampleCount
        )
    }

    public func setupVertices(inputSize: C7Size) -> [Float]? {
        triangleVertices.flatMap { point in
            [point.x * 2 - 1, 1 - point.y * 2, 0, 0]
        }
    }

    private static func triangulate(_ points: [FreePoint2D]) throws -> [FreePoint2D] {
        var twiceSignedArea: Float = 0
        for index in points.indices {
            let nextIndex = (index + 1) % points.count
            twiceSignedArea += points[index].x * points[nextIndex].y
                - points[nextIndex].x * points[index].y
        }
        let signedArea = twiceSignedArea * 0.5
        guard abs(signedArea) > 1e-7 else {
            throw ValidationError.degeneratePolygon
        }

        let isCounterClockwise = signedArea > 0
        var remaining = Array(points.indices)
        var triangles: [FreePoint2D] = []
        triangles.reserveCapacity((points.count - 2) * 3)
        var attemptsWithoutEar = 0

        while remaining.count > 3 {
            let index = attemptsWithoutEar % remaining.count
            let previous = remaining[(index - 1 + remaining.count) % remaining.count]
            let current = remaining[index]
            let next = remaining[(index + 1) % remaining.count]
            let a = points[previous]
            let b = points[current]
            let c = points[next]
            let cross = crossProduct(a, b, c)
            let isConvex = isCounterClockwise ? cross > 1e-7 : cross < -1e-7
            let containsPoint = remaining.contains { candidate in
                guard candidate != previous, candidate != current, candidate != next else { return false }
                return point(points[candidate], liesInTriangle: a, b, c)
            }

            if isConvex && !containsPoint {
                if isCounterClockwise {
                    triangles += [a, b, c]
                } else {
                    triangles += [a, c, b]
                }
                remaining.remove(at: index)
                attemptsWithoutEar = 0
            } else {
                attemptsWithoutEar += 1
                if attemptsWithoutEar >= remaining.count {
                    throw ValidationError.nonSimplePolygon
                }
            }
        }

        let final = remaining.map { points[$0] }
        triangles += isCounterClockwise ? final : [final[0], final[2], final[1]]
        return triangles
    }

    private static func crossProduct(_ a: FreePoint2D, _ b: FreePoint2D, _ c: FreePoint2D) -> Float {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    private static func point(_ point: FreePoint2D, liesInTriangle a: FreePoint2D, _ b: FreePoint2D, _ c: FreePoint2D) -> Bool {
        let ab = crossProduct(a, b, point)
        let bc = crossProduct(b, c, point)
        let ca = crossProduct(c, a, point)
        let hasNegative = ab < -1e-7 || bc < -1e-7 || ca < -1e-7
        let hasPositive = ab > 1e-7 || bc > 1e-7 || ca > 1e-7
        return !(hasNegative && hasPositive)
    }
}

//
//  ProjectiveTransform.swift
//  Harbeth
//
//  Created by Condy on 2026/11/15.
//

import CoreGraphics
import Foundation
import simd

/// 双精度投影原语。调用方决定退化时拒绝、保留原点还是采用仿射回退。
public struct ProjectiveTransform: Equatable, Sendable {
    public let values: [Double]
    public static let identity = try! Self(values: [1, 0, 0, 0, 1, 0, 0, 0, 1])

    public init(values: [Double]) throws {
        guard values.count == 9, values.allSatisfy(\.isFinite) else {
            throw HarbethError.configurationInvalid("A projective matrix requires nine finite values")
        }
        self.values = values
    }

    /// 四角顺序为左上、右上、左下、右下；失败不隐式改变调用方的几何策略。
    public static func unitSquare(to points: [CGPoint]) -> Self? {
        guard points.count == 4, points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let p = points.map { SIMD2(Double($0.x), Double($0.y)) }
        let p00 = p[0], p10 = p[1], p01 = p[2], p11 = p[3]
        let dx1 = p10.x - p11.x
        let dx2 = p01.x - p11.x
        let dx3 = p00.x - p10.x - p01.x + p11.x
        let dy1 = p10.y - p11.y
        let dy2 = p01.y - p11.y
        let dy3 = p00.y - p10.y - p01.y + p11.y
        let denominator = dx1 * dy2 - dx2 * dy1
        guard abs(denominator) > 0.000001 else { return nil }
        let g = (dx3 * dy2 - dx2 * dy3) / denominator
        let h = (dx1 * dy3 - dx3 * dy1) / denominator
        return try? Self(values: [
            p10.x - p00.x + g * p10.x, p01.x - p00.x + h * p01.x, p00.x,
            p10.y - p00.y + g * p10.y, p01.y - p00.y + h * p01.y, p00.y,
            g, h, 1
        ])
    }

    public func applying(to point: CGPoint) -> CGPoint? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        let x = Double(point.x), y = Double(point.y)
        let denominator = values[6] * x + values[7] * y + values[8]
        guard abs(denominator) > 0.000001 else { return nil }
        return CGPoint(
            x: (values[0] * x + values[1] * y + values[2]) / denominator,
            y: (values[3] * x + values[4] * y + values[5]) / denominator
        )
    }

    public func inverted() -> Self? {
        let m = values
        let determinant = m[0] * (m[4] * m[8] - m[5] * m[7]) -
            m[1] * (m[3] * m[8] - m[5] * m[6]) +
            m[2] * (m[3] * m[7] - m[4] * m[6])
        guard abs(determinant) > 0.000001 else { return nil }
        return try? Self(values: [
            (m[4] * m[8] - m[5] * m[7]) / determinant,
            (m[2] * m[7] - m[1] * m[8]) / determinant,
            (m[1] * m[5] - m[2] * m[4]) / determinant,
            (m[5] * m[6] - m[3] * m[8]) / determinant,
            (m[0] * m[8] - m[2] * m[6]) / determinant,
            (m[2] * m[3] - m[0] * m[5]) / determinant,
            (m[3] * m[7] - m[4] * m[6]) / determinant,
            (m[1] * m[6] - m[0] * m[7]) / determinant,
            (m[0] * m[4] - m[1] * m[3]) / determinant
        ])
    }

    public var simdMatrix: simd_double3x3 {
        simd_double3x3(columns: (
            SIMD3(values[0], values[3], values[6]),
            SIMD3(values[1], values[4], values[7]),
            SIMD3(values[2], values[5], values[8])
        ))
    }
}

//
//  RenderMeshWarp.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation

/// 单帧稀疏目标网格形变。
///
/// `controlPoints` 按行优先排列，从左上到右下。每个点都是归一化输出坐标中的
/// 目标位置：`(0, 0)` 为输出左上，`(1, 1)` 为输出右下。允许使用范围外坐标，
/// 它们会把几何移动到固定输入尺寸输出画布之外。源纹理坐标始终是对应的规则网格，
/// 因此修改一个控制点只会把该源网格位置移动到指定目标位置。
public struct RenderMeshWarp: RenderProtocol {

    public static let maximumControlPointCount = 4096

    public let rows: Int
    public let columns: Int
    public let controlPoints: [FreePoint2D]

    public var modifier: ModifierEnum {
        .render(vertex: "meshWarpVertex", fragment: "meshWarpFragment")
    }

    public var renderSamplerConsumption: RenderSamplerConsumption {
        .runtimeBound
    }

    public var renderVertexStride: Int { 4 }

    /// 创建一个输出画布保持输入纹理尺寸的网格形变。
    ///
    /// - Parameters:
    ///   - rows: 控制点行数，至少为二。
    ///   - columns: 控制点列数，至少为二。
    ///   - controlPoints: 行优先目标点，数量必须等于 `rows * columns`，且所有坐标必须有限。
    public init(rows: Int, columns: Int, controlPoints: [FreePoint2D]) throws {
        guard rows >= 2, columns >= 2 else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderMeshWarp", reason: "rows and columns must both be at least 2; got \(rows)x\(columns)"
            )
        }
        guard rows <= Int.max / columns else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderMeshWarp", reason: "grid dimensions overflow; got \(rows)x\(columns)"
            )
        }

        let expectedCount = rows * columns
        guard expectedCount <= Self.maximumControlPointCount else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderMeshWarp", reason: "control point count \(expectedCount) exceeds \(Self.maximumControlPointCount)"
            )
        }
        guard controlPoints.count == expectedCount else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderMeshWarp", reason: "expected \(expectedCount) control points, got \(controlPoints.count)"
            )
        }

        guard let invalidIndex = controlPoints.firstIndex(where: { !$0.x.isFinite || !$0.y.isFinite }) else {
            self.rows = rows
            self.columns = columns
            self.controlPoints = controlPoints
            return
        }
        throw HarbethError.renderPrimitiveValidationFailed(
            primitive: "RenderMeshWarp", reason: "control point \(invalidIndex) is non-finite"
        )
    }

    /// 按指定控制点数量创建未形变的规则网格。
    public static func identity(rows: Int, columns: Int) throws -> RenderMeshWarp {
        guard rows >= 2, columns >= 2 else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderMeshWarp", reason: "rows and columns must both be at least 2; got \(rows)x\(columns)"
            )
        }
        guard rows <= Int.max / columns else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderMeshWarp", reason: "grid dimensions overflow; got \(rows)x\(columns)"
            )
        }
        let expectedCount = rows * columns
        guard expectedCount <= Self.maximumControlPointCount else {
            throw HarbethError.renderPrimitiveValidationFailed(
                primitive: "RenderMeshWarp", reason: "control point count \(expectedCount) exceeds \(Self.maximumControlPointCount)"
            )
        }
        let points = (0..<rows).flatMap { row in
            (0..<columns).map { column in
                FreePoint2D(
                    x: Float(column) / Float(columns - 1),
                    y: Float(row) / Float(rows - 1)
                )
            }
        }
        return try RenderMeshWarp(rows: rows, columns: columns, controlPoints: points)
    }

    public func setupVertices(inputSize: C7Size) -> [Float]? {
        var vertices: [Float] = []
        let rowPairCount = rows - 1
        let expectedVertexCount = rowPairCount * columns * 2 + max(rowPairCount - 1, 0) * 2
        vertices.reserveCapacity(expectedVertexCount * renderVertexStride)

        for row in 0..<rowPairCount {
            for column in 0..<columns {
                appendVertex(row: row, column: column, to: &vertices)
                appendVertex(row: row + 1, column: column, to: &vertices)
            }

            guard row < rowPairCount - 1 else { continue }
            appendVertex(row: row + 1, column: columns - 1, to: &vertices)
            appendVertex(row: row + 1, column: 0, to: &vertices)
        }
        return vertices
    }

    private func appendVertex(row: Int, column: Int, to vertices: inout [Float]) {
        let point = controlPoints[row * columns + column]
        let u = Float(column) / Float(columns - 1)
        let v = Float(row) / Float(rows - 1)
        vertices += [point.x * 2 - 1, 1 - point.y * 2, u, v]
    }
}

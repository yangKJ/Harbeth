//
//  Transform3DLayout.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation
import QuartzCore
import simd

struct Transform3DLayout {

    static func defaultViewport(for inputSize: CGSize) -> CGRect {
        CGRect(
            x: -0.5 * inputSize.width,
            y: -0.5 * inputSize.height,
            width: inputSize.width,
            height: inputSize.height
        )
    }

    static func resolvedViewport(for inputSize: CGSize,
                                 transform: CATransform3D,
                                 fieldOfView: Float,
                                 viewportMode: Transform3DViewportMode) -> CGRect {
        switch viewportMode {
        case .original:
            return defaultViewport(for: inputSize)
        case .minimumEnclosing:
            return minimumEnclosingViewport(for: inputSize, transform: transform, fieldOfView: fieldOfView)
        }
    }

    static func minimumEnclosingViewport(for inputSize: CGSize,
                                         transform: CATransform3D,
                                         fieldOfView: Float) -> CGRect {
        let imageRect = defaultViewport(for: inputSize)
        let matrix = transformMatrix(inputSize: inputSize, viewport: imageRect, transform: transform, fieldOfView: fieldOfView)
        var points = transformedCorners(of: imageRect, matrix: matrix)

        for index in points.indices where points[index].w != 0 {
            points[index] /= points[index].w
            points[index] *= simd_float4(Float(imageRect.width) / 2, Float(imageRect.height) / 2, 1, 1)
        }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return imageRect
        }

        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX),
            height: CGFloat(maxY - minY)
        )
    }

    static func projectedVertices(for inputSize: CGSize,
                                  transform: CATransform3D,
                                  fieldOfView: Float,
                                  viewport: CGRect) -> [Float] {
        let imageRect = defaultViewport(for: inputSize)
        let matrix = transformMatrix(inputSize: inputSize, viewport: viewport, transform: transform, fieldOfView: fieldOfView)
        let corners = transformedCorners(of: imageRect, matrix: matrix)

        return [
            corners[0].x, corners[0].y, corners[0].w, 0, 1,
            corners[1].x, corners[1].y, corners[1].w, 1, 1,
            corners[2].x, corners[2].y, corners[2].w, 0, 0,
            corners[3].x, corners[3].y, corners[3].w, 1, 0,
        ]
    }

    private static func transformedCorners(of imageRect: CGRect, matrix: simd_float4x4) -> [simd_float4] {
        let tl = simd_float4(Float(imageRect.minX), Float(imageRect.minY), 0, 1)
        let tr = simd_float4(Float(imageRect.maxX), Float(imageRect.minY), 0, 1)
        let bl = simd_float4(Float(imageRect.minX), Float(imageRect.maxY), 0, 1)
        let br = simd_float4(Float(imageRect.maxX), Float(imageRect.maxY), 0, 1)
        return [tl, tr, bl, br].map { simd_mul($0, matrix) }
    }

    private static func transformMatrix(inputSize: CGSize,
                                        viewport: CGRect,
                                        transform: CATransform3D,
                                        fieldOfView: Float) -> simd_float4x4 {
        if fieldOfView > 0 {
            let near = -Float(inputSize.width) * 0.5 / tan(fieldOfView / 2.0)
            let far = near * 2.0
            let transformToCameraCoordinates = CATransform3DMakeTranslation(0, 0, CGFloat(near))
            let combinedTransform = CATransform3DConcat(transform, transformToCameraCoordinates)
            let transformMatrix = Matrix4x4(transform3D: combinedTransform).to_factor()
            let perspectiveMatrix = makePerspectiveMatrix(
                left: Float(viewport.minX),
                right: Float(viewport.maxX),
                top: Float(viewport.minY),
                bottom: Float(viewport.maxY),
                near: near,
                far: far
            )
            return simd_mul(transformMatrix, perspectiveMatrix)
        } else {
            let transformMatrix = Matrix4x4(transform3D: transform).to_factor()
            let orthographicMatrix = makeOrthographicMatrix(
                left: Float(viewport.minX),
                right: Float(viewport.maxX),
                top: Float(viewport.minY),
                bottom: Float(viewport.maxY),
                near: 0,
                far: 1
            )
            return simd_mul(transformMatrix, orthographicMatrix)
        }
    }

    private static func makeOrthographicMatrix(left: Float,
                                               right: Float,
                                               top: Float,
                                               bottom: Float,
                                               near: Float,
                                               far: Float) -> simd_float4x4 {
        let r_l = right - left
        let t_b = bottom - top
        let f_n = far - near
        let tx = -(right + left) / (right - left)
        let ty = -(top + bottom) / (bottom - top)
        let tz = -(far + near) / (far - near)

        var matrix = simd_float4x4()
        matrix.columns.0 = SIMD4<Float>(2.0 / r_l, 0, 0, tx)
        matrix.columns.1 = SIMD4<Float>(0, 2.0 / t_b, 0, ty)
        matrix.columns.2 = SIMD4<Float>(0, 0, 2.0 / f_n, tz)
        matrix.columns.3 = SIMD4<Float>(0, 0, 0, 1)
        return matrix
    }

    private static func makePerspectiveMatrix(left: Float,
                                              right: Float,
                                              top: Float,
                                              bottom: Float,
                                              near: Float,
                                              far: Float) -> simd_float4x4 {
        let near = -near
        let far = -far

        var matrix = simd_float4x4()
        matrix.columns.0 = SIMD4<Float>(2 * near / (right - left), 0, (right + left) / (right - left), 0)
        matrix.columns.1 = SIMD4<Float>(0, 2 * near / (bottom - top), (top + bottom) / (bottom - top), 0)
        matrix.columns.2 = SIMD4<Float>(0, 0, -(far) / (far - near), -(far * near) / (far - near))
        matrix.columns.3 = SIMD4<Float>(0, 0, -1, 0)
        return matrix
    }
}

public enum Transform3DViewportMode: Int, Codable, Sendable, CaseIterable {
    case original = 0
    case minimumEnclosing = 1
}

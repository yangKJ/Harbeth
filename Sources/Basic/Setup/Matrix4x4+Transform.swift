//
//  Matrix4x4+Transform.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import Darwin

extension Matrix4x4 {
    /// 常见4x4转换矩阵，需要配合顶点着色器
    /// A common 4x4 conversion matrix requires a vertex shader.
    /// See: https://medium.com/macoclock/augmented-reality-911-transform-matrix-4x4-af91a9718246
    public struct Transform { }
}

extension Matrix4x4.Transform {
    
    public static let identity = Matrix4x4(values: [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    ])
    
    public static func scaling(_ scale: Float) -> Matrix4x4 {
        var matrix = Matrix4x4.Transform.identity
        matrix.values[0] = scale
        matrix.values[5] = scale
        matrix.values[10] = scale
        return matrix
    }
    
    public static func translationX(_ x: Float, y: Float, z: Float) -> Matrix4x4 {
        var matrix = Matrix4x4.Transform.identity
        matrix.values[12] = x
        matrix.values[13] = y
        matrix.values[14] = z
        return matrix
    }
    
    public static func rotationX(_ x: Float, y: Float, z: Float) -> Matrix4x4 {
        var matrix = Matrix4x4.Transform.identity
        matrix.values[0] = cos(y) * cos(z)
        matrix.values[4] = cos(z) * sin(x) * sin(y) - cos(x) * sin(z)
        matrix.values[8] = cos(x) * cos(z) * sin(y) + sin(x) * sin(z)
        matrix.values[1] = cos(y) * sin(z)
        matrix.values[5] = cos(x) * cos(z) + sin(x) * sin(y) * sin(z)
        matrix.values[9] = -cos(z) * sin(x) + cos(x) * sin(y) * sin(z)
        matrix.values[2] = -sin(y)
        matrix.values[6] = cos(y) * sin(x)
        matrix.values[10] = cos(x) * cos(y)
        return matrix
    }
}

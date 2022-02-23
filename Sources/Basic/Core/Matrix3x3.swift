//
//  MatrixKernel.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation
import simd

extension Matrix3x3 {
    
    public static let size = MemoryLayout<matrix_float3x3>.size
    
    public func to_matrix_float3x3() -> matrix_float3x3 {
        return matrix_float3x3([
            SIMD3<Float>(values[0], values[1], values[2]),
            SIMD3<Float>(values[3], values[4], values[5]),
            SIMD3<Float>(values[6], values[7], values[8]),
        ])
    }
}

/// 常见 3x3 矩阵卷积内核，考线性代数时刻😪
/// Common 3x3 matrix convolution kernel
extension Matrix3x3 {
    /// 原始矩阵，空卷积核
    /// The original matrix, the empty convolution kernel
    public static let `default` = Matrix3x3(values: [
        0.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 0.0,
    ])
    
    public static let identity = Matrix3x3(values: [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    ])
    
    /// 边缘检测矩阵
    /// Edge detection matrix
    public static let edgedetect = Matrix3x3(values: [
        -1.0, -1.0, -1.0,
        -1.0,  8.0, -1.0,
        -1.0, -1.0, -1.0,
    ])
    
    /// 浮雕矩阵
    /// Anaglyph matrix
    public static let embossment = Matrix3x3(values: [
        -2.0, 0.0, 0.0,
         0.0, 1.0, 0.0,
         0.0, 0.0, 2.0,
    ])
    
    /// 45度的浮雕滤波器
    /// A 45 degree emboss filter
    public static let embossment45 = Matrix3x3(values: [
        -1.0, -1.0, 0.0,
        -1.0,  0.0, 1.0,
         0.0,  1.0, 1.0,
    ])
    
    /// 侵蚀矩阵
    /// Matrix erosion
    public static let morphological = Matrix3x3(values: [
        1.0, 1.0, 1.0,
        1.0, 1.0, 1.0,
        1.0, 1.0, 1.0,
    ])
    
    /// 拉普拉斯算子，边缘检测算子
    /// Laplace operator, edge detection operator
    public static func laplance(_ iterations: Float) -> Matrix3x3 {
        let xxx = iterations
        return Matrix3x3(values: [
             0.0, -1.0,  0.0,
            -1.0,  xxx, -1.0,
             0.0, -1.0,  0.0,
        ])
    }
    
    /// 锐化矩阵
    /// Sharpening matrix
    public static func sharpen(_ iterations: Float) -> Matrix3x3 {
        let cc = (8 * iterations + 1)
        let xx = (-iterations)
        return Matrix3x3(values: [
            xx, xx, xx,
            xx, cc, xx,
            xx, xx, xx,
        ])
    }
    
    /// Sobel矩阵图像边缘提取，求梯度比较常用
    /// Sobel matrix image edge extraction, gradient is more commonly used
    public static func sobel(_ orientation: Bool) -> Matrix3x3 {
        if orientation {
            return Matrix3x3(values: [
                -1.0, 0.0, 1.0,
                -2.0, 0.0, 2.0,
                -1.0, 0.0, 1.0,
            ])
        } else {
            return Matrix3x3(values: [
                -1.0, -2.0, -1.0,
                 0.0,  0.0,  0.0,
                 1.0,  2.0,  1.0,
            ])
        }
    }
}

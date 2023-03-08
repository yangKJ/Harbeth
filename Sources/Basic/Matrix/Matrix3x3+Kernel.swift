//
//  MatrixKernel.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation

extension Matrix3x3 {
    /// 常见 3x3 矩阵卷积内核，考线性代数时刻😪
    /// Common 3x3 matrix convolution kernel
    public struct Kernel { }
}

extension Matrix3x3.Kernel {
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
    
    /// BT.601, which is the standard for SDTV.
    public static let to601 = Matrix3x3(values: [
        1.164,  1.164, 1.164,
        0.000, -0.392, 2.017,
        1.596, -0.813, 0.000,
    ])
    
    /// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
    public static let to601FullRange = Matrix3x3(values: [
        1.0,  1.000, 1.000,
        0.0, -0.343, 1.765,
        1.4, -0.711, 0.000,
    ])
    
    /// BT.709, which is the standard for HDTV.
    public static let to709 = Matrix3x3(values: [
        1.164,  1.164, 1.164,
        0.000, -0.213, 2.112,
        1.793, -0.533, 0.000,
    ])
}

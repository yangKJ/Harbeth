//
//  MatrixKernel.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation

/// 常见 3x3 矩阵卷积内核，考线性代数时刻😪
/// Common 3x3 matrix convolution kernel
extension Matrix3x3 {
    /// 原始矩阵
    public static let `default` = Matrix3x3(values: [
        0.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 0.0,
    ])
    
    /// 高斯矩阵
    public static let gaussian = Matrix3x3(values: [
        1.0, 2.0, 1.0,
        2.0, 4.0, 2.0,
        1.0, 2.0, 1.0,
    ])
    
    /// 边缘检测矩阵
    public static let edgedetect = Matrix3x3(values: [
        -1.0, -1.0, -1.0,
        -1.0,  8.0, -1.0,
        -1.0, -1.0, -1.0,
    ])
    
    /// 浮雕矩阵
    public static let emboss = Matrix3x3(values: [
        -2.0, 0.0, 0.0,
         0.0, 1.0, 0.0,
         0.0, 0.0, 2.0,
    ])
    
    /// 侵蚀矩阵
    public static let morphological = Matrix3x3(values: [
        1.0, 1.0, 1.0,
        1.0, 1.0, 1.0,
        1.0, 1.0, 1.0,
    ])
}

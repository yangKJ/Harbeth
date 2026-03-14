//
//  Matrix4x4.swift
//  Harbeth
//
//  Created by Condy on 2022/2/23.
//

import Foundation
import simd

public struct Matrix4x4: Matrix {
    
    public typealias MatrixType = matrix_float4x4
    
    public var values: [Float]
    
    public init(values: [Float]) {
        if values.count != 16 {
            HarbethError.failed("There must be 16 values for 4x4 Matrix.")
        }
        self.values = values
    }
    
    /// The 4x4 matrix is obtained by CATransform3D
    public init(transform3D: CATransform3D) {
        let values: [Float] = [
            Float(transform3D.m11), Float(transform3D.m12), Float(transform3D.m13), Float(transform3D.m14),
            Float(transform3D.m21), Float(transform3D.m22), Float(transform3D.m23), Float(transform3D.m24),
            Float(transform3D.m31), Float(transform3D.m32), Float(transform3D.m33), Float(transform3D.m34),
            Float(transform3D.m41), Float(transform3D.m42), Float(transform3D.m43), Float(transform3D.m44),
        ]
        self.init(values: values)
    }
    
    public init(transform: CGAffineTransform) {
        self.init(transform3D: CATransform3DMakeAffineTransform(transform))
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([Float].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
    
    public func to_factor() -> matrix_float4x4 {
        return matrix_float4x4(rows: [
            SIMD4<Float>(values[0], values[4], values[8],  values[12]),
            SIMD4<Float>(values[1], values[5], values[9],  values[13]),
            SIMD4<Float>(values[2], values[6], values[10], values[14]),
            SIMD4<Float>(values[3], values[7], values[11], values[15]),
        ])
    }
}

// MARK: - color matrix

extension Matrix4x4 {
    /// 常见4x4颜色矩阵，考线性代数时刻😪
    /// 第一行的值决定了红色值，第二行决定绿色，第三行蓝色，第四行是透明通道值
    /// Common 4x4 color matrix
    /// See: https://medium.com/macoclock/coreimage-911-color-matrix-4x4-50a7098414f4
    public struct Color { }
}

extension Matrix4x4.Color {
    /// 单位矩阵，无效果
    public static let identity = Matrix4x4(values: [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    ])
    
    // MARK: - 灰度与黑白效果
    
    /// 灰度图矩阵，平均值法
    public static let gray = Matrix4x4(values: [
        0.33, 0.33, 0.33, 0.0,
        0.33, 0.33, 0.33, 0.0,
        0.33, 0.33, 0.33, 0.0,
        0.00, 0.00, 0.00, 1.0,
    ])
    
    /// 黑白效果，基于人眼敏感度
    public static let blackAndWhite = Matrix4x4(values: [
        0.299, 0.587, 0.114, 0.0,
        0.299, 0.587, 0.114, 0.0,
        0.299, 0.587, 0.114, 0.0,
        0.000, 0.000, 0.000, 1.0,
    ])
    
    // MARK: - 复古与怀旧效果
    
    /// 棕褐色，老照片
    public static let sepia = Matrix4x4(values: [
        0.3588, 0.7044, 0.1368, 0.0,
        0.2990, 0.5870, 0.1140, 0.0,
        0.2392, 0.4696, 0.0912, 0.0,
        0.0000, 0.0000, 0.0000, 1.0,
    ])
    
    /// 怀旧效果
    public static let nostalgic = Matrix4x4(values: [
        0.272, 0.534, 0.131, 0.0,
        0.349, 0.686, 0.168, 0.0,
        0.393, 0.769, 0.189, 0.0,
        0.000, 0.000, 0.000, 1.0,
    ])
    
    /// 复古效果
    public static let retroStyle = Matrix4x4(values: [
        0.50, 0.50, 0.50, 0.0,
        0.33, 0.33, 0.33, 0.0,
        0.25, 0.25, 0.25, 0.0,
        0.00, 0.00, 0.00, 1.0,
    ])
    
    /// 宝丽来彩色
    public static let polaroid = Matrix4x4(values: [
        1.4380, -0.062, -0.062, 0.0,
        -0.122, 1.3780, -0.122, 0.0,
        -0.016, -0.016, 1.4830, 0.0,
        -0.030, 0.0500, -0.020, 1.0,
    ])
    
    // MARK: - 颜色调整
    
    /// 反相效果
    public static let invert = Matrix4x4(values: [
        -1.0,  0.0,  0.0, 0.0,
         0.0, -1.0,  0.0, 0.0,
         0.0,  0.0, -1.0, 0.0,
         1.0,  1.0,  1.0, 1.0,
    ])
    
    /// 负片效果
    public static let negative = Matrix4x4(values: [
        -1.0,  0.0,  0.0, 0.0,
         0.0, -1.0,  0.0, 0.0,
         0.0,  0.0, -1.0, 0.0,
         1.0,  1.0,  1.0, 1.0,
    ])
    
    /// 暖色调
    public static let warm = Matrix4x4(values: [
        1.0, 0.0,  0.0,  0.0,
        0.0, 0.95, 0.0,  0.0,
        0.0, 0.0,  0.85, 0.0,
        0.0, 0.05, 0.15, 1.0,
    ])
    
    /// 冷色调
    public static let cool = Matrix4x4(values: [
        0.85, 0.0,  0.0, 0.0,
        0.0,  0.95, 0.0, 0.0,
        1.0,  0.0,  1.0, 0.0,
        0.15, 0.05, 0.0, 1.0,
    ])
    
    /// 蓝调效果
    public static let blueTint = Matrix4x4(values: [
        0.8, 0.0, 0.0, 0.0,
        0.0, 0.8, 0.0, 0.0,
        1.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.1, 1.0,
    ])
    
    /// 日落效果
    public static let sunset = Matrix4x4(values: [
        1.0, 0.0,  0.0, 0.0,
        0.5, 1.0,  0.0, 0.0,
        0.0, 0.0,  0.5, 0.0,
        0.1, 0.05, 0.0, 1.0,
    ])
    
    /// 肤色增强
    public static let skinToneEnhance = Matrix4x4(values: [
        1.0, 0.0,  0.0,  0.0,
        0.0, 1.05, 0.0,  0.0,
        0.0, 0.0,  0.95, 0.0,
        0.0, 0.02, 0.0,  1.0,
    ])
    
    /// 鲜艳效果
    public static let vibrance = Matrix4x4(values: [
        1.4,  -0.1, -0.1, 0.0,
        -0.1, 1.4,  -0.1, 0.0,
        -0.1, -0.1, 1.4,  0.0,
        0.0,  0.0,  0.0,  1.0,
    ])
    
    // MARK: - 通道操作
    
    /// 绿色通道加倍
    public static let greenDouble = Matrix4x4(values: [
        1.0, 0.0, 0.0, 0.0,
        0.0, 2.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    ])
    
    /// 天蓝色变绿色，天蓝色是由绿色和蓝色叠加
    public static let skyblue_turns_green = Matrix4x4(values: [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    ])
    
    /// 去掉绿色和蓝色
    public static let remove_green_blue = Matrix4x4(values: [
        1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    ])
    
    /// 红色绿色对调位置
    public static let replaced_red_green = Matrix4x4(values: [
        0.0, 1.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    ])
    
    /// maps RGB to BGR (rows permuted)
    public static let rgb_to_bgr = Matrix4x4(values: [
        0.22, 0.22, 0.90, 0.0,
        0.11, 0.70, 0.44, 0.0,
        0.90, 0.11, 0.11, 0.0,
        0.00, 0.00, 0.00, 1.0
    ])
    
    // MARK: - 特殊效果
    
    /// 白色剪影
    /// In case you have to produce a white silhouette you need to supply data to the last column of the color matrix.
    public static let white_silhouette = Matrix4x4(values: [
        0.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 0.0, 1.0,
    ])
    
    /// When you have a premultiplied image, where RGB is multiplied by Alpha, decreasing A value you decrease a whole opacity of RGB.
    /// Thus, any underlying layer becomes partially visible from under our translucent image.
    /// - Parameter alpha: Alpha, 0 ~ 1
    public static func decreasingOpacity(_ alpha: Float) -> Matrix4x4 {
        var matrix = Matrix4x4.Color.identity
        matrix.values[15] = min(1.0, max(0.0, alpha))
        return matrix
    }
    
    /// Rotates the color matrix by alpha degrees clockwise about the red component axis.
    /// - Parameter angle: rotation degree.
    /// - Returns: 4x4 color matrix.
    public static func axix_red_rotate(_ angle: Float) -> Matrix4x4 {
        var matrix = Matrix4x4.Color.identity
        let radians = angle * Float.pi / 180.0
        matrix.values[5] = cos(radians)
        matrix.values[6] = sin(radians)
        matrix.values[9] = -sin(radians)
        matrix.values[10] = cos(radians)
        return matrix
    }
    
    /// Rotates the color matrix by alpha degrees clockwise about the green component axis.
    /// - Parameter angle: rotation degree.
    /// - Returns: 4x4 color matrix.
    public static func axix_green_rotate(_ angle: Float) -> Matrix4x4 {
        var matrix = Matrix4x4.Color.identity
        let radians = angle * Float.pi / 180.0
        matrix.values[0] = cos(radians)
        matrix.values[2] = -sin(radians)
        matrix.values[7] = sin(radians)
        matrix.values[9] = cos(radians)
        return matrix
    }
    
    /// Rotates the color matrix by alpha degrees clockwise about the blue component axis.
    /// - Parameter angle: rotation degree.
    /// - Returns: 4x4 color matrix.
    public static func axix_blue_rotate(_ angle: Float) -> Matrix4x4 {
        var matrix = Matrix4x4.Color.identity
        let radians = angle * Float.pi / 180.0
        matrix.values[0] = cos(radians)
        matrix.values[1] = sin(radians)
        matrix.values[4] = -sin(radians)
        matrix.values[5] = cos(radians)
        return matrix
    }
}

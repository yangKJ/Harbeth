//
//  Vector4.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import simd

/// 4维向量
public struct Vector4: Matrix {
    
    public static let zero: Vector4 = .init(values: [0, 0, 0, 0])
    
    public typealias MatrixType = vector_float4
    
    public var values: [Float]
    
    public init(values: [Float]) {
        if values.count != 4 {
            HarbethError.failed("There must be four values for Vector4.")
        }
        self.values = values
    }
    
    public init(color: C7Color) {
        let (red, green, blue, alpha) = color.c7.toRGBA()
        self.init(values: [red, green, blue, alpha])
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([Float].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
    
    public func to_factor() -> vector_float4 {
        vector_float4.init(x: values[0], y: values[1], z: values[2], w: values[3])
    }
}

// MARK: - color vector

extension Vector4 {
    /// 常见颜色四维向量
    public struct Color { }
}

extension Vector4.Color {
    // MARK: - 基础向量
    
    /// 零向量
    public static let zero = Vector4(values: [0.0, 0.0, 0.0, 0.0])
    
    /// 原始向量
    public static let origin = Vector4(values: [0.0, 0.0, 0.0, 0.0])
    
    /// 全一向量
    public static let one = Vector4(values: [1.0, 1.0, 1.0, 1.0])
    
    /// 红色向量
    public static let red = Vector4(values: [1.0, 0.0, 0.0, 0.0])
    
    /// 绿色向量
    public static let green = Vector4(values: [0.0, 1.0, 0.0, 0.0])
    
    /// 蓝色向量
    public static let blue = Vector4(values: [0.0, 0.0, 1.0, 0.0])
    
    /// 白色向量
    public static let white = Vector4(values: [1.0, 1.0, 1.0, 0.0])
    
    /// 黑色向量
    public static let black = Vector4(values: [0.0, 0.0, 0.0, 0.0])
    
    // MARK: - 颜色调整向量
    
    /// 亮度增加
    public static let brightness = Vector4(values: [0.2, 0.2, 0.2, 0.0])
    
    /// 亮度减少
    public static let dimness = Vector4(values: [-0.2, -0.2, -0.2, 0.0])
    
    /// 饱和度增加
    public static let saturation = Vector4(values: [0.1, 0.1, 0.1, 0.0])
    
    /// 对比度增加
    public static let contrast = Vector4(values: [0.1, 0.1, 0.1, 0.0])
    
    /// 伽马调整
    public static let gamma = Vector4(values: [0.05, 0.05, 0.05, 0.0])
    
    /// 曝光调整
    public static let exposure = Vector4(values: [0.15, 0.15, 0.15, 0.0])
    
    // MARK: - 色调调整向量
    
    /// 暖色，将rgb通道的颜色添加相应的红/绿色值
    /// Warm color, add the color of the rgb channel to the corresponding red/green value.
    public static let warm = Vector4(values: [0.3, 0.3, 0.0, 0.0])
    
    /// 冷色，将rgb通道的颜色添加相应的蓝色值
    /// Cold color, add the color of the rgb channel to the corresponding blue value.
    public static let cool = Vector4(values: [0.0, 0.0, 0.3, 0.0])
    
    /// 棕褐色调
    public static let sepia = Vector4(values: [0.2, 0.1, 0.0, 0.0])
    
    /// 复古色调
    public static let vintage = Vector4(values: [0.15, 0.1, 0.05, 0.0])
    
    /// 怀旧色调
    public static let nostalgic = Vector4(values: [0.1, 0.1, 0.0, 0.0])
    
    /// 日落色调
    public static let sunset = Vector4(values: [0.3, 0.1, 0.0, 0.0])
    
    /// 蓝色调
    public static let blueTint = Vector4(values: [0.0, 0.0, 0.2, 0.0])
    
    /// 绿色调
    public static let greenTint = Vector4(values: [0.0, 0.2, 0.0, 0.0])
    
    /// 红色调
    public static let redTint = Vector4(values: [0.2, 0.0, 0.0, 0.0])
    
    // MARK: - 特殊效果向量
    
    /// 反相
    public static let invert = Vector4(values: [-1.0, -1.0, -1.0, 0.0])
    
    /// 灰度
    public static let grayscale = Vector4(values: [0.299, 0.587, 0.114, 0.0])
    
    /// 高对比度
    public static let highContrast = Vector4(values: [0.2, 0.2, 0.2, 0.0])
    
    /// 低对比度
    public static let lowContrast = Vector4(values: [-0.1, -0.1, -0.1, 0.0])
    
    /// 锐化
    public static let sharpen = Vector4(values: [0.1, 0.1, 0.1, 0.0])
    
    /// 柔和
    public static let soft = Vector4(values: [-0.05, -0.05, -0.05, 0.0])
}

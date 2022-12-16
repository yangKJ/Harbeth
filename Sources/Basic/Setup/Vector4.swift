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
    
    public typealias MatrixType = vector_float4
    
    public var values: [Float]
    
    public init(values: [Float]) {
        if values.count != 4 {
            C7FailedErrorInDebug("There must be four values for Vector4.")
        }
        self.values = values
    }
    
    public init(color: C7Color) {
        let (red, green, blue, alpha) = color.mt.toRGBA()
        self.init(values: [red, green, blue, alpha])
    }
    
    public func to_factor() -> vector_float4 {
        vector_float4.init(x: values[0], y: values[1], z: values[2], w: values[3])
    }
}

extension Vector4 { public struct Color { } }

extension Vector4.Color {
    
    /// 原始
    public static let origin = Vector4(values: [0.0, 0.0, 0.0, 0.0])
    
    /// 暖色，将rgb通道的颜色添加相应的红/绿色值
    /// Warm color, add the color of the rgb channel to the corresponding red/green value.
    public static let warm = Vector4(values: [0.3, 0.3, 0.0, 0.0])
    
    /// 冷色，将rgb通道的颜色添加相应的蓝色值
    /// Cold color, add the color of the rgb channel to the corresponding blue value.
    public static let cool_tone = Vector4(values: [0.0, 0.0, 0.3, 0.0])
}

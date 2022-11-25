//
//  Vector4+Color.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

extension Vector4 {
    public struct Color { }
}

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

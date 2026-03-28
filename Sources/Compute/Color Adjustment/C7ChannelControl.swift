//
//  C7ChannelControl.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 通道控制滤镜
/// Channel control filter
public struct C7ChannelControl: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    /// 红色通道强度 (-1.0 ~ 1.0)，0.0代表原图
    /// Red channel intensity (-1.0 ~ 1.0), 0.0 represents original image
    @Clamping(range.min...range.max) public var red: Float = range.value
    
    /// 绿色通道强度 (-1.0 ~ 1.0)，0.0代表原图
    /// Green channel intensity (-1.0 ~ 1.0), 0.0 represents original image
    @Clamping(range.min...range.max) public var green: Float = range.value
    
    /// 蓝色通道强度 (-1.0 ~ 1.0)，0.0代表原图
    /// Blue channel intensity (-1.0 ~ 1.0), 0.0 represents original image
    @Clamping(range.min...range.max) public var blue: Float = range.value
    
    /// 透明度通道强度 (0.0 ~ 1.0)
    /// Alpha channel intensity (0.0 ~ 1.0)
    @ZeroOneRange public var alpha: Float = R.iRange.value
    
    /// 混合强度 (0.0 ~ 1.0)，0.0代表原图
    /// Blend intensity (0.0 ~ 1.0), 0.0 represents original image
    @ZeroOneRange public var blend: Float = 0.0
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ChannelControl")
    }
    
    public var factors: [Float] {
        return [red, green, blue, alpha, blend]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public init(red: Float = 0, green: Float = 0, blue: Float = 0, alpha: Float = 1.0, blend: Float = 0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.blend = blend
    }
}

//
//  C7BlendChromaKey.swift
//  Harbeth
//
//  Created by Condy on 2024/6/30.
//

import Foundation
import MetalKit

/// 色度键控滤镜（绿幕抠图）
/// Chroma key filter (green screen matting)
public struct C7BlendChromaKey: C7FilterProtocol {
    
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    /// 阈值，默认0.4
    public var threshold: Float = 0.4
    /// 平滑度，默认0.1
    public var smoothing: Float = 0.1
    /// 替换颜色，默认白色
    public var color: C7Color = .white
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7BlendChromaKey")
    }
    
    public var factors: [Float] {
        let (red, green, blue, _) = color.c7.toRGBA()
        return [threshold, smoothing, red, green, blue, intensity]
    }
    
    public init(threshold: Float = 0.4, smoothing: Float = 0.1, color: C7Color = .white) {
        self.threshold = threshold
        self.smoothing = smoothing
        self.color = color
    }
}

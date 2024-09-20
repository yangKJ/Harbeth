//
//  C7ColorCGASpace.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// 图像CGA色彩滤镜，形成黑、浅蓝、紫色块的画面
public struct C7ColorCGASpace: C7FilterProtocol {
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorCGASpace")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public init() { }
}

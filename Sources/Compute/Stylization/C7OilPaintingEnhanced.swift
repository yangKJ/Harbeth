//
//  C7OilPaintingEnhanced.swift
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

import Foundation

/// 增强版油画效果滤镜
/// Enhanced oil painting effect filter
public struct C7OilPaintingEnhanced: C7FilterProtocol {
    
    /// Brush size, from 1.0 to 10.0, default 3.0
    public var brushSize: Float = 3.0
    
    /// Color intensity, from 0.0 to 2.0, default 1.0
    public var intensity: Float = 1.0
    
    /// Smoothing factor, from 0.0 to 1.0, default 0.5
    @ZeroOneRange public var smoothing: Float = 0.5
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7OilPaintingEnhanced")
    }
    
    public var factors: [Float] {
        return [brushSize, intensity, smoothing]
    }
    
    public init(brushSize: Float = 3.0, intensity: Float = 1.0, smoothing: Float = 0.5) {
        self.brushSize = brushSize
        self.intensity = intensity
        self.smoothing = smoothing
    }
}

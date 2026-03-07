//
//  C7SharpenEnhanced.swift
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

import Foundation

/// 增强版锐化滤镜
/// Enhanced sharpen filter
public struct C7SharpenEnhanced: C7FilterProtocol {
    
    /// Sharpen intensity, from 0.0 to 5.0, default 1.0
    public var intensity: Float = 1.0
    
    /// Edge threshold, from 0.0 to 1.0, default 0.1
    @ZeroOneRange public var threshold: Float = 0.1
    
    /// Kernel size, from 1 to 5, default 3
    public var kernelSize: Int = 3
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7SharpenEnhanced")
    }
    
    public var factors: [Float] {
        return [intensity, threshold, Float(kernelSize)]
    }
    
    public init(intensity: Float = 1.0, threshold: Float = 0.1, kernelSize: Int = 3) {
        self.intensity = intensity
        self.threshold = threshold
        self.kernelSize = min(max(kernelSize, 1), 5)
    }
}

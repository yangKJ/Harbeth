//
//  C7LuminanceAdaptiveContrast.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// 基于像素亮度自适应调整对比度，暗部增强对比度，亮部降低对比度
/// Adaptive contrast adjustment based on pixel brightness,
/// dark part enhances contrast, bright part reduces contrast
public struct C7LuminanceAdaptiveContrast: C7FilterProtocol {
    
    @ZeroOneRange public var amount: Float
    
    @ZeroOneRange public var adaptivity: Float = 0.5
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7LuminanceAdaptiveContrast")
    }
    
    public var factors: [Float] {
        return [amount.isFinite ? amount : 0, adaptivity.isFinite ? adaptivity : 0.5]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, precision: .float32,
              dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: .point)
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }

    public init(amount: Float, adaptivity: Float = 0.5) {
        self.amount = amount
        self.adaptivity = adaptivity
    }
}

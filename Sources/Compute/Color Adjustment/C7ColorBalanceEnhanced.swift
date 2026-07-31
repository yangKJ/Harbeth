//
//  C7ColorBalanceEnhanced.swift
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

import Foundation

/// 增强版色彩平衡滤镜
/// Enhanced color balance filter
public struct C7ColorBalanceEnhanced: C7FilterProtocol {

    /// Shadows color adjustment, from -1.0 to 1.0 for each channel
    public var shadows: C7Color = .zero

    /// Midtones color adjustment, from -1.0 to 1.0 for each channel
    public var midtones: C7Color = .zero

    /// Highlights color adjustment, from -1.0 to 1.0 for each channel
    public var highlights: C7Color = .zero

    /// Balance strength, from 0.0 to 1.0, default 1.0
    @ZeroOneRange public var strength: Float = 1.0

    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorBalanceEnhanced")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        return [
            KernelParameterBinding(name: "strength", index: 0, stage: .compute, value: .float(strength)),
            KernelParameterBinding(name: "shadows", index: 1, stage: .compute, value: .float3(colorAdjustment(shadows))),
            KernelParameterBinding(name: "midtones", index: 2, stage: .compute, value: .float3(colorAdjustment(midtones))),
            KernelParameterBinding(name: "highlights", index: 3, stage: .compute, value: .float3(colorAdjustment(highlights)))
        ]
    }

    private func colorAdjustment(_ color: C7Color) -> SIMD3<Float> {
        color.c7.toSIMD3() * 2 - SIMD3<Float>(repeating: 1)
    }

    public init(shadows: C7Color = .zero, midtones: C7Color = .zero, highlights: C7Color = .zero, strength: Float = 1.0) {
        self.shadows = shadows
        self.midtones = midtones
        self.highlights = highlights
        self.strength = strength
    }
}

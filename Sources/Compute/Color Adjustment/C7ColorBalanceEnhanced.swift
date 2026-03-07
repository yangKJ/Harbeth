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
    
    public var factors: [Float] {
        return [strength]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        
        // Convert colors to RGB values in range [-1, 1]
        let shadowsRGB = colorToRGB(shadows)
        let midtonesRGB = colorToRGB(midtones)
        let highlightsRGB = colorToRGB(highlights)
        
        var shadowsFactor = simd_float3(shadowsRGB.r, shadowsRGB.g, shadowsRGB.b)
        var midtonesFactor = simd_float3(midtonesRGB.r, midtonesRGB.g, midtonesRGB.b)
        var highlightsFactor = simd_float3(highlightsRGB.r, highlightsRGB.g, highlightsRGB.b)
        
        computeEncoder.setBytes(&shadowsFactor, length: MemoryLayout<simd_float3>.size, index: index)
        computeEncoder.setBytes(&midtonesFactor, length: MemoryLayout<simd_float3>.size, index: index + 1)
        computeEncoder.setBytes(&highlightsFactor, length: MemoryLayout<simd_float3>.size, index: index + 2)
    }
    
    private func colorToRGB(_ color: C7Color) -> (r: Float, g: Float, b: Float) {
        let (red, green, blue, _) = color.c7.toRGBA()
        // Convert from [0, 1] to [-1, 1]
        return (r: (red * 2.0) - 1.0, g: (green * 2.0) - 1.0, b: (blue * 2.0) - 1.0)
    }
    
    public init(shadows: C7Color = .zero, midtones: C7Color = .zero, highlights: C7Color = .zero, strength: Float = 1.0) {
        self.shadows = shadows
        self.midtones = midtones
        self.highlights = highlights
        self.strength = strength
    }
}

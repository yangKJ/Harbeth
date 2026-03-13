//
//  C7ColorBurnEnhancedBlend.swift
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

import Foundation
import MetalKit

/// 增强版颜色加深混合模式
/// Enhanced color burn blend mode
public struct C7ColorBurnEnhancedBlend: C7FilterProtocol {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Strength of the color burn effect, from 0.0 to 2.0, default 1.0
    public var strength: Float = 1.0
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorBurnEnhancedBlend")
    }
    
    public var factors: [Float] {
        return [intensity, strength]
    }
    
    public var otherInputTextures: C7InputTextures {
        return blendTexture == nil ? [] : [blendTexture!]
    }
    
    private let blendTexture: MTLTexture?
    
    public init(with image: C7Image, strength: Float = 1.0, intensity: Float = 1.0) {
        let overTexture = image.cgImage?.c7.toTexture()
        self.init(with: overTexture, strength: strength, intensity: intensity)
    }
    
    public init(with blendTexture: MTLTexture?, strength: Float = 1.0, intensity: Float = 1.0) {
        self.blendTexture = blendTexture
        self.strength = strength
        self.intensity = intensity
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
}

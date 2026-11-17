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
public struct C7ColorBurnEnhancedBlend: C7FilterProtocol, BlitProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.1, max: 2.0, value: 1.0)
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Strength of the color burn effect, from 0.1 to 2.0, default 1.0
    @Clamping(range.min...range.max) public var strength: Float = range.value
    
    public var modifier: ModifierEnum {
        return isBypassed ? .blit : .compute(kernel: "C7ColorBurnEnhancedBlend")
    }
    
    public var factors: [Float] {
        return [intensity.isFinite ? intensity : 0, strength.isFinite ? strength : 1]
    }
    
    public var otherInputTextures: C7InputTextures {
        return isBypassed ? [] : [blendTexture!]
    }
    
    private var isBypassed: Bool { blendTexture == nil || !intensity.isFinite || intensity <= 0 }
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: isBypassed ? .preserveInput : .premultiplied, precision: .float32,
              dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: isBypassed ? .point : .dynamic,
              coordinateDependency: isBypassed ? .local : .fullImage, globalDependency: isBypassed ? .none : .imageDimensions)
    }
    public var kernelOutputContract: RenderOutputContract { isBypassed ? .preserveInput : .premultipliedColorInput }
    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        try PipelineIdentityFilter().encode(commandBuffer: commandBuffer, textures: textures)
    }

    private let blendTexture: MTLTexture?
    
    public init(with image: C7Image, strength: Float = range.value, intensity: Float = 1.0) {
        let overTexture = image.cgImage?.c7.toTexture()
        self.init(with: overTexture, strength: strength, intensity: intensity)
    }
    
    public init(with blendTexture: MTLTexture?, strength: Float = range.value, intensity: Float = 1.0) {
        self.blendTexture = blendTexture
        self.strength = strength
        self.intensity = intensity
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
    
    public func updateStrength(_ strength: CGFloat) -> Self {
        var copy = self
        copy.strength = Float(strength)
        return copy
    }
}

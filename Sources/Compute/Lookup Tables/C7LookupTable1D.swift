//
//  C7LookupTable1D.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 一维查找表滤镜，使用一维查找表（1D LUT）来调整图像的色彩
/// One-dimensional lookup table filter
public struct C7LookupTable1D: C7FilterProtocol {
    
    /// 调整效果的强度 (0.0 ~ 1.0)
    /// Adjustment intensity (0.0 ~ 1.0)
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7LookupTable1D")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: C7InputTextures {
        return lookupTexture == nil ? [] : [lookupTexture!]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .dualTexture
    }
    
    private var lookupTexture: MTLTexture?
    
    public init(lookupImage: C7Image?, intensity: Float = 1.0) {
        self.lookupTexture = lookupImage?.cgImage?.c7.toTexture()
        self.intensity = intensity
    }
    
    public init(image: C7Image?, intensity: Float = 1.0) {
        self.init(lookupImage: image, intensity: intensity)
    }
    
    public init(name: String, intensity: Float = 1.0) {
        self.init(lookupImage: R.image(name), intensity: intensity)
    }
    
    public init(lookupTexture: MTLTexture, intensity: Float = 1.0) {
        self.lookupTexture = lookupTexture
        self.intensity = intensity
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
    
    public func updateLookupImage(_ image: C7Image?) -> Self {
        var copy = self
        copy.lookupTexture = image?.cgImage?.c7.toTexture()
        return copy
    }
}

//
//  C7ColorLookup512x512.swift
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

import Foundation
import MetalKit

/// 512x512 颜色查找表滤镜，用于高质量的颜色调整
/// 512x512 color search table filter for high-quality color
public struct C7ColorLookup512x512: C7FilterProtocol {
    
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorLookup512x512")
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
    
    public mutating func updateLookupImage(_ image: C7Image?) -> Self {
        self.lookupTexture = image?.cgImage?.c7.toTexture()
        return self
    }
}

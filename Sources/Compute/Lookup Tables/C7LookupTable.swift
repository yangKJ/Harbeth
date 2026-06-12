//
//  C7LookupTable.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/9.
//

import Foundation
import MetalKit

/// LUT映射滤镜（2D LUT）
/// See: https://juejin.cn/post/7169096223100829709
public struct C7LookupTable: C7FilterProtocol {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public private(set) var resourceName: String?
    public private(set) var resourceBundleName: String?
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7LookupTable")
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
        self.resourceName = nil
        self.resourceBundleName = nil
    }
    
    public init(image: C7Image?, intensity: Float = 1.0) {
        self.init(lookupImage: image, intensity: intensity)
    }
    
    public init(name: String, forResource resource: String = "Harbeth", intensity: Float = 1.0) {
        self.init(lookupImage: R.image(name, forResource: resource), intensity: intensity)
        self.resourceName = name
        self.resourceBundleName = resource
    }
    
    public init(lookupTexture: MTLTexture, intensity: Float = 1.0) {
        self.lookupTexture = lookupTexture
        self.intensity = intensity
        self.resourceName = nil
        self.resourceBundleName = nil
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

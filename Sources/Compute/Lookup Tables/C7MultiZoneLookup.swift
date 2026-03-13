//
//  C7MultiZoneLookup.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 多区域查找表滤镜
/// Multi-zone lookup table filter
public struct C7MultiZoneLookup: C7FilterProtocol {
    
    /// 阴影区域阈值 (0.0 ~ 1.0)
    /// Shadow area threshold (0.0 ~ 1.0)
    @ZeroOneRange public var shadowThreshold: Float = 0.3
    
    /// 高光区域阈值 (0.0 ~ 1.0)
    /// Highlight area threshold (0.0 ~ 1.0)
    @ZeroOneRange public var highlightThreshold: Float = 0.7
    
    /// 区域过渡宽度 (0.0 ~ 0.5)
    /// Transition width between zones (0.0 ~ 0.5)
    @Clamping(0.0...0.5) public var transitionWidth: Float = 0.1
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7MultiZoneLookup")
    }
    
    public var factors: [Float] {
        return [shadowThreshold, highlightThreshold, transitionWidth]
    }
    
    public var otherInputTextures: C7InputTextures {
        var textures: [MTLTexture] = []
        if let shadow = shadowLookupTexture {
            textures.append(shadow)
        }
        if let midtone = midtoneLookupTexture {
            textures.append(midtone)
        }
        if let highlight = highlightLookupTexture {
            textures.append(highlight)
        }
        return textures
    }
    
    private var shadowLookupTexture: MTLTexture?
    private var midtoneLookupTexture: MTLTexture?
    private var highlightLookupTexture: MTLTexture?
    
    public init(shadowThreshold: Float = 0.3, highlightThreshold: Float = 0.7, transitionWidth: Float = 0.1, shadowLookupTexture: MTLTexture, midtoneLookupTexture: MTLTexture, highlightLookupTexture: MTLTexture) {
        self.shadowThreshold = shadowThreshold
        self.highlightThreshold = highlightThreshold
        self.transitionWidth = transitionWidth
        self.shadowLookupTexture = shadowLookupTexture
        self.midtoneLookupTexture = midtoneLookupTexture
        self.highlightLookupTexture = highlightLookupTexture
    }
    
    public init(shadowThreshold: Float = 0.3, highlightThreshold: Float = 0.7, transitionWidth: Float = 0.1, shadowLookupImage: C7Image, midtoneLookupImage: C7Image, highlightLookupImage: C7Image) {
        self.shadowThreshold = shadowThreshold
        self.highlightThreshold = highlightThreshold
        self.transitionWidth = transitionWidth
        self.shadowLookupTexture = shadowLookupImage.cgImage?.c7.toTexture()
        self.midtoneLookupTexture = midtoneLookupImage.cgImage?.c7.toTexture()
        self.highlightLookupTexture = highlightLookupImage.cgImage?.c7.toTexture()
    }
    
    public init(shadowThreshold: Float = 0.3, highlightThreshold: Float = 0.7, transitionWidth: Float = 0.1, shadowLookupName: String, midtoneLookupName: String, highlightLookupName: String) {
        self.shadowThreshold = shadowThreshold
        self.highlightThreshold = highlightThreshold
        self.transitionWidth = transitionWidth
        self.shadowLookupTexture = R.image(shadowLookupName)?.cgImage?.c7.toTexture()
        self.midtoneLookupTexture = R.image(midtoneLookupName)?.cgImage?.c7.toTexture()
        self.highlightLookupTexture = R.image(highlightLookupName)?.cgImage?.c7.toTexture()
    }
    
    public func updateShadowLookupTexture(_ texture: MTLTexture) -> Self {
        var copy = self
        copy.shadowLookupTexture = texture
        return copy
    }
    
    public func updateMidtoneLookupTexture(_ texture: MTLTexture) -> Self {
        var copy = self
        copy.midtoneLookupTexture = texture
        return copy
    }
    
    public func updateHighlightLookupTexture(_ texture: MTLTexture) -> Self {
        var copy = self
        copy.highlightLookupTexture = texture
        return copy
    }
    
    public func updateZones(shadowThreshold: Float, highlightThreshold: Float, transitionWidth: Float) -> Self {
        var copy = self
        copy.shadowThreshold = shadowThreshold
        copy.highlightThreshold = highlightThreshold
        copy.transitionWidth = transitionWidth
        return copy
    }
}

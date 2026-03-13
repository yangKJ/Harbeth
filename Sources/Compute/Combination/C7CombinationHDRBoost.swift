//
//  C7CombinationHDRBoost.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 高动态范围增强组合滤镜
/// High dynamic range boost combination filter
public final class C7CombinationHDRBoost: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// HDR strength, ranging from 0.0 to 2.0
    public var hdrStrength: Float = 1.0
    
    /// Contrast adjustment, ranging from 1.0 to 3.0, with 1.0 being the original
    public var contrast: Float = 1.5 {
        didSet {
            contrastFilter.contrast = contrast
        }
    }
    
    /// Saturation adjustment, ranging from 1.0 to 1.5, with 1.0 being the original
    public var saturation: Float = 1.1 {
        didSet {
            saturationFilter.saturation = saturation
        }
    }
    
    /// Sharpness adjustment, ranging from 0.0 to 2.0
    public var sharpness: Float = 0.8 {
        didSet {
            sharpenFilter.sharpeness = sharpness
        }
    }
    
    /// Highlights adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var highlights: Float = -0.4 {
        didSet {
            highlightShadowFilter.highlights = (highlights + 1.0) * 0.5
        }
    }
    
    /// Shadows adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var shadows: Float = 0.3 {
        didSet {
            highlightShadowFilter.shadows = (shadows + 1.0) * 0.5
        }
    }
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationHDRBoost")
    }
    
    public override var factors: [Float] {
        return [intensity, hdrStrength]
    }
    
    public override var otherInputTextures: C7InputTextures {
        return intermediateTextures
    }
    
    private var contrastFilter: C7Contrast
    private var saturationFilter: C7Saturation
    private var sharpenFilter: C7Sharpen
    private var highlightShadowFilter: C7HighlightShadow
    
    public init(intensity: Float = 0.8) {
        self.intensity = intensity
        self.contrastFilter = C7Contrast(contrast: 1.5)
        self.saturationFilter = C7Saturation(saturation: 1.1)
        self.sharpenFilter = C7Sharpen(sharpness: 0.8)
        self.highlightShadowFilter = C7HighlightShadow(highlights: 0.3, shadows: 0.65)
        super.init()
    }
    
    /// Prepare intermediate textures for the HDR boost filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
        // Apply highlight and shadow adjustment
        let highlightShadowDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try highlightShadowFilter.applyAtTexture(form: currentTexture, to: highlightShadowDest, for: buffer)
        
        // Apply contrast adjustment
        let contrastDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try contrastFilter.applyAtTexture(form: currentTexture, to: contrastDest, for: buffer)
        
        // Apply saturation adjustment
        let saturationDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try saturationFilter.applyAtTexture(form: currentTexture, to: saturationDest, for: buffer)
        
        // Apply sharpening
        let sharpenDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try sharpenFilter.applyAtTexture(form: currentTexture, to: sharpenDest, for: buffer)
        
        intermediateTextures.append(currentTexture)
        return intermediateTextures
    }
    
    /// Cleanup resources after processing
    public override func cleanupIntermediateTextures() {
        // Return textures to pool if possible
        for texture in intermediateTextures {
            Shared.shared.texturePool?.enqueueTexture(texture)
        }
        super.cleanupIntermediateTextures()
    }
}

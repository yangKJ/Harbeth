//
//  C7CombinationModernHDR.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// 现代HDR效果组合滤镜
/// Modern HDR effect combination filter
public final class C7CombinationModernHDR: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Contrast adjustment, ranging from 1.0 to 3.0, with 1.0 being the original
    public var contrast: Float = 1.8 {
        didSet {
            contrastFilter.contrast = contrast
        }
    }
    
    /// Saturation adjustment, ranging from 1.0 to 2.0, with 1.0 being the original
    public var saturation: Float = 1.3 {
        didSet {
            saturationFilter.saturation = saturation
        }
    }
    
    /// Sharpness adjustment, ranging from 0.0 to 2.0
    public var sharpness: Float = 1.2 {
        didSet {
            sharpenFilter.sharpeness = sharpness
        }
    }
    
    /// Highlights adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var highlights: Float = -0.3 {
        didSet {
            // Convert from [-1.0, 1.0] to [0.0, 1.0] for C7HighlightShadow
            // For highlights: -1.0 (darken) -> 0.0, 0.0 (original) -> 0.5, 1.0 (lighten) -> 1.0
            highlightShadowFilter.highlights = (highlights + 1.0) * 0.5
        }
    }
    
    /// Shadows adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var shadows: Float = 0.2 {
        didSet {
            // Convert from [-1.0, 1.0] to [0.0, 1.0] for C7HighlightShadow
            // For shadows: -1.0 (darken) -> 0.0, 0.0 (original) -> 0.5, 1.0 (lighten) -> 1.0
            highlightShadowFilter.shadows = (shadows + 1.0) * 0.5
        }
    }
    
    /// Clarity adjustment, ranging from 0.0 to 1.0
    public var clarity: Float = 0.4
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationModernHDR")
    }
    
    public override var factors: [Float] {
        return [intensity, clarity]
    }
    
    public override var otherInputTextures: C7InputTextures {
        // Return the processed textures from intermediateTextures
        return intermediateTextures
    }
    
    private var contrastFilter: C7Contrast
    private var saturationFilter: C7Saturation
    private var sharpenFilter: C7Sharpen
    private var highlightShadowFilter: C7HighlightShadow
    
    public init(intensity: Float = 0.8) {
        self.intensity = intensity
        self.contrastFilter = C7Contrast(contrast: 1.8)
        self.saturationFilter = C7Saturation(saturation: 1.3)
        self.sharpenFilter = C7Sharpen(sharpness: 1.2)
        // Initialize with converted parameters: -0.3 -> 0.35, 0.2 -> 0.6
        self.highlightShadowFilter = C7HighlightShadow(highlights: (-0.3 + 1.0) * 0.5, shadows: (0.2 + 1.0) * 0.5)
        super.init()
    }
    
    /// Prepare intermediate textures for the modern HDR filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
        // Apply combined highlight and shadow adjustment using single Metal filter
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

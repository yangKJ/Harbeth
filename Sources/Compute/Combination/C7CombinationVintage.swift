//
//  C7CombinationVintage.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// 复古胶片效果组合滤镜
/// Vintage film effect combination filter
public final class C7CombinationVintage: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Sepia tone intensity, ranging from 0.0 to 1.0
    public var sepiaIntensity: Float = 0.8 {
        didSet {
            sepiaFilter.intensity = sepiaIntensity
        }
    }
    
    /// Vignette intensity, ranging from 0.0 to 1.0
    public var vignetteIntensity: Float = 0.6 {
        didSet {
            // Convert intensity to start and end values for C7Vignette
            vignetteFilter.start = 0.2
            vignetteFilter.end = 0.2 + (0.8 - 0.2) * (1.0 - vignetteIntensity)
        }
    }
    
    /// Contrast adjustment, ranging from 0.5 to 1.5, with 1.0 being the original
    public var contrast: Float = 0.9 {
        didSet {
            contrastFilter.contrast = contrast
        }
    }
    
    /// Saturation adjustment, ranging from 0.5 to 1.5, with 1.0 being the original
    public var saturation: Float = 0.7 {
        didSet {
            saturationFilter.saturation = saturation
        }
    }
    
    /// Grain intensity, ranging from 0.0 to 1.0
    public var grainIntensity: Float = 0.4 {
        didSet {
            grainFilter.grain = grainIntensity
        }
    }
    
    /// Dust and scratches intensity, ranging from 0.0 to 1.0
    public var dustIntensity: Float = 0.2
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationVintage")
    }
    
    public override var factors: [Float] {
        return [intensity, dustIntensity]
    }
    
    public override var otherInputTextures: C7InputTextures {
        // Return the processed textures from intermediateTextures
        return intermediateTextures
    }
    
    private var sepiaFilter: C7Sepia
    private var vignetteFilter: C7Vignette
    private var contrastFilter: C7Contrast
    private var saturationFilter: C7Saturation
    private var grainFilter: C7Granularity
    
    public init(intensity: Float = 0.8) {
        self.intensity = intensity
        self.sepiaFilter = C7Sepia(intensity: 0.8)
        self.vignetteFilter = C7Vignette(start: 0.2, end: 0.8, color: .zero)
        self.contrastFilter = C7Contrast(contrast: 0.9)
        self.saturationFilter = C7Saturation(saturation: 0.7)
        self.grainFilter = C7Granularity(grain: 0.4)
        super.init()
    }
    
    /// Prepare intermediate textures for the vintage filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
        // Apply sepia tone
        let sepiaDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try sepiaFilter.applyAtTexture(form: currentTexture, to: sepiaDest, for: buffer)
        
        // Apply contrast adjustment
        let contrastDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try contrastFilter.applyAtTexture(form: currentTexture, to: contrastDest, for: buffer)
        
        // Apply saturation adjustment
        let saturationDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try saturationFilter.applyAtTexture(form: currentTexture, to: saturationDest, for: buffer)
        
        // Apply grain effect
        let grainDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try grainFilter.applyAtTexture(form: currentTexture, to: grainDest, for: buffer)
        
        // Apply vignette
        let vignetteDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try vignetteFilter.applyAtTexture(form: currentTexture, to: vignetteDest, for: buffer)
        
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

//
//  C7CombinationVintageFilm.swift
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

import Foundation

/// 复古电影风格组合滤镜
/// Vintage film style combination filter
public final class C7CombinationVintageFilm: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Grain intensity, ranging from 0.0 to 1.0
    public var grainIntensity: Float = 0.6 {
        didSet {
            grainIntensity = max(0.0, min(1.0, grainIntensity))
        }
    }
    
    /// Vignette strength, ranging from 0.0 to 1.0
    public var vignette: Float = 0.4
    
    /// Sepia tone intensity, ranging from 0.0 to 1.0
    public var sepiaTone: Float = 0.8
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationVintageFilm")
    }
    
    public override var factors: [Float] {
        return [intensity, grainIntensity, vignette, sepiaTone]
    }
    
    public override var otherInputTextures: C7InputTextures {
        return intermediateTextures
    }
    
    private var sepiaFilter: C7Sepia
    private var contrastFilter: C7Contrast
    private var saturationFilter: C7Saturation
    
    public init(intensity: Float = 1.0) {
        self.intensity = intensity
        self.sepiaFilter = C7Sepia(intensity: 0.8)
        self.contrastFilter = C7Contrast(contrast: 1.2)
        self.saturationFilter = C7Saturation(saturation: 0.8)
        super.init()
    }
    
    /// Prepare intermediate textures for the vintage film filter
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
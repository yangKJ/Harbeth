//
//  C7CombinationCyberpunk.swift
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

import Foundation

/// 赛博朋克风格组合滤镜
/// Cyberpunk style combination filter
public final class C7CombinationCyberpunk: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Neon glow strength, ranging from 0.0 to 2.0
    public var neonGlow: Float = 0.8 {
        didSet {
            neonGlow = max(0.0, min(2.0, neonGlow))
        }
    }
    
    /// Contrast adjustment, ranging from 1.0 to 3.0, with 1.0 being the original
    public var contrast: Float = 1.8 {
        didSet {
            contrastFilter.contrast = contrast
        }
    }
    
    /// Saturation adjustment, ranging from 1.0 to 3.0, with 1.0 being the original
    public var saturation: Float = 1.5 {
        didSet {
            saturationFilter.saturation = saturation
        }
    }
    
    /// Color shift intensity, ranging from 0.0 to 1.0
    public var colorShift: Float = 0.6
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationCyberpunk")
    }
    
    public override var factors: [Float] {
        return [intensity, neonGlow, colorShift]
    }
    
    public override var otherInputTextures: C7InputTextures {
        return intermediateTextures
    }
    
    private var contrastFilter: C7Contrast
    private var saturationFilter: C7Saturation
    private var sharpenFilter: C7Sharpen
    
    public init(intensity: Float = 1.0) {
        self.intensity = intensity
        self.contrastFilter = C7Contrast(contrast: 1.8)
        self.saturationFilter = C7Saturation(saturation: 1.5)
        self.sharpenFilter = C7Sharpen(sharpness: 1.0)
        super.init()
    }
    
    /// Prepare intermediate textures for the cyberpunk filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
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
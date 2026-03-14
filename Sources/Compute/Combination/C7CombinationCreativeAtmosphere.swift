//
//  C7CombinationCreativeAtmosphere.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 创意氛围组合滤镜
/// Creative atmosphere combination filter
public final class C7CombinationCreativeAtmosphere: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Atmosphere type: 0 = Warm Glow, 1 = Cool Blue, 2 = Golden Hour, 3 = Moody
    public var atmosphereType: Int = 0
    
    /// Glow intensity, ranging from 0.0 to 1.0
    public var glowIntensity: Float = 0.3 {
        didSet {
            gaussianBlurFilter.radius = glowIntensity * 3.0
        }
    }
    
    /// Color shift intensity, ranging from 0.0 to 1.0
    public var colorShift: Float = 0.2
    
    /// Vignette intensity, ranging from 0.0 to 1.0
    public var vignetteIntensity: Float = 0.4 {
        didSet {
            vignetteFilter.start = 0.3
            vignetteFilter.end = 0.3 + (0.8 - 0.3) * (1.0 - vignetteIntensity)
        }
    }
    
    /// Contrast adjustment, ranging from 0.8 to 1.2, with 1.0 being the original
    public var contrast: Float = 1.0 {
        didSet {
            contrastFilter.contrast = contrast
        }
    }
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationCreativeAtmosphere")
    }
    
    public override var factors: [Float] {
        return [intensity, Float(atmosphereType), colorShift]
    }
    
    public override var otherInputTextures: C7InputTextures {
        return intermediateTextures
    }
    
    private var gaussianBlurFilter: MPSGaussianBlur
    private var contrastFilter: C7Contrast
    private var vignetteFilter: C7Vignette
    
    public init(intensity: Float = 1.0) {
        self.intensity = intensity
        self.gaussianBlurFilter = MPSGaussianBlur(radius: 0.9)
        self.contrastFilter = C7Contrast(contrast: 1.0)
        self.vignetteFilter = C7Vignette(start: 0.3, end: 0.8, color: .zero)
        super.init()
    }
    
    /// Prepare intermediate textures for the creative atmosphere filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
        // Apply subtle blur for glow effect
        let blurDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try gaussianBlurFilter.applyAtTexture(form: currentTexture, to: blurDest, for: buffer)
        
        // Apply contrast adjustment
        let contrastDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try contrastFilter.applyAtTexture(form: currentTexture, to: contrastDest, for: buffer)
        
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

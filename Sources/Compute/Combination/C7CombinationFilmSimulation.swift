//
//  C7CombinationFilmSimulation.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 现代胶片模拟组合滤镜
/// Modern film simulation combination filter
public final class C7CombinationFilmSimulation: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Film type selection: 0 = Standard, 1 = Vivid, 2 = Neutral, 3 = Black & White
    public var filmType: Int = 0
    
    /// Grain intensity, ranging from 0.0 to 1.0
    public var grainIntensity: Float = 0.3 {
        didSet {
            grainFilter.grain = grainIntensity
        }
    }
    
    /// Contrast adjustment, ranging from 0.8 to 1.5, with 1.0 being the original
    public var contrast: Float = 1.1 {
        didSet {
            contrastFilter.contrast = contrast
        }
    }
    
    /// Saturation adjustment, ranging from 0.8 to 1.3, with 1.0 being the original
    public var saturation: Float = 1.05 {
        didSet {
            saturationFilter.saturation = saturation
        }
    }
    
    /// Vignette intensity, ranging from 0.0 to 1.0
    public var vignetteIntensity: Float = 0.2 {
        didSet {
            vignetteFilter.start = 0.4
            vignetteFilter.end = 0.4 + (0.9 - 0.4) * (1.0 - vignetteIntensity)
        }
    }
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationFilmSimulation")
    }
    
    public override var factors: [Float] {
        return [intensity, Float(filmType)]
    }
    
    public override var otherInputTextures: C7InputTextures {
        return intermediateTextures
    }
    
    private var grainFilter: C7Granularity
    private var contrastFilter: C7Contrast
    private var saturationFilter: C7Saturation
    private var vignetteFilter: C7Vignette
    
    public init(intensity: Float = 0.8) {
        self.intensity = intensity
        self.grainFilter = C7Granularity(grain: 0.3)
        self.contrastFilter = C7Contrast(contrast: 1.1)
        self.saturationFilter = C7Saturation(saturation: 1.05)
        self.vignetteFilter = C7Vignette(start: 0.4, end: 0.9, color: .zero)
        super.init()
    }
    
    /// Prepare intermediate textures for the film simulation filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
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

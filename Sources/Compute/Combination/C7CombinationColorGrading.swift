//
//  C7CombinationColorGrading.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 电影级色彩分级组合滤镜
/// Cinematic color grading combination filter
public final class C7CombinationColorGrading: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Color temperature adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var temperature: Float = 0.0 {
        didSet {
            temperatureFilter.temperature = temperature
        }
    }
    
    /// Tint adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var tint: Float = 0.0 {
        didSet {
            temperatureFilter.tint = tint
        }
    }
    
    /// Contrast adjustment, ranging from 0.5 to 2.0, with 1.0 being the original
    public var contrast: Float = 1.2 {
        didSet {
            contrastFilter.contrast = contrast
        }
    }
    
    /// Saturation adjustment, ranging from 0.0 to 2.0, with 1.0 being the original
    public var saturation: Float = 0.9 {
        didSet {
            saturationFilter.saturation = saturation
        }
    }
    
    /// Highlights adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var highlights: Float = -0.2 {
        didSet {
            highlightShadowFilter.highlights = (highlights + 1.0) * 0.5
        }
    }
    
    /// Shadows adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var shadows: Float = 0.1 {
        didSet {
            highlightShadowFilter.shadows = (shadows + 1.0) * 0.5
        }
    }
    
    /// Midtones adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var midtones: Float = 0.0
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationColorGrading")
    }
    
    public override var factors: [Float] {
        return [intensity, midtones]
    }
    
    public override var otherInputTextures: C7InputTextures {
        return intermediateTextures
    }
    
    private var temperatureFilter: C7Temperature
    private var contrastFilter: C7Contrast
    private var saturationFilter: C7Saturation
    private var highlightShadowFilter: C7HighlightShadow
    
    public init(intensity: Float = 1.0) {
        self.intensity = intensity
        self.temperatureFilter = C7Temperature(temperature: 0.0, tint: 0.0)
        self.contrastFilter = C7Contrast(contrast: 1.2)
        self.saturationFilter = C7Saturation(saturation: 0.9)
        self.highlightShadowFilter = C7HighlightShadow(highlights: 0.4, shadows: 0.55)
        super.init()
    }
    
    /// Prepare intermediate textures for the color grading filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
        // Apply temperature and tint adjustment
        let temperatureDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try temperatureFilter.applyAtTexture(form: currentTexture, to: temperatureDest, for: buffer)
        
        // Apply contrast adjustment
        let contrastDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try contrastFilter.applyAtTexture(form: currentTexture, to: contrastDest, for: buffer)
        
        // Apply saturation adjustment
        let saturationDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try saturationFilter.applyAtTexture(form: currentTexture, to: saturationDest, for: buffer)
        
        // Apply highlight and shadow adjustment
        let highlightShadowDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try highlightShadowFilter.applyAtTexture(form: currentTexture, to: highlightShadowDest, for: buffer)
        
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

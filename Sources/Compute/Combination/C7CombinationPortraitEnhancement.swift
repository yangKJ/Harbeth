//
//  C7CombinationPortraitEnhancement.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 智能人像增强组合滤镜
/// Smart portrait enhancement combination filter
public final class C7CombinationPortraitEnhancement: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Skin smoothing strength, ranging from 0.0 to 1.0
    public var skinSmoothing: Float = 0.5 {
        didSet {
            bilateralBlurFilter.distanceNormalizationFactor = 8.0 - (skinSmoothing * 6.0)
        }
    }
    
    /// Skin tone adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var skinTone: Float = 0.1
    
    /// Eye enhancement strength, ranging from 0.0 to 1.0
    public var eyeEnhancement: Float = 0.3
    
    /// Teeth whitening strength, ranging from 0.0 to 1.0
    public var teethWhitening: Float = 0.2
    
    /// Face brightening, ranging from 0.0 to 1.0
    public var faceBrightening: Float = 0.2 {
        didSet {
            exposureFilter.exposure = faceBrightening * 0.3
        }
    }
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationPortraitEnhancement")
    }
    
    public override var factors: [Float] {
        return [intensity, skinTone, eyeEnhancement, teethWhitening]
    }
    
    public override var otherInputTextures: C7InputTextures {
        return intermediateTextures
    }
    
    private var bilateralBlurFilter: C7BilateralBlur
    private var exposureFilter: C7Exposure
    private var saturationFilter: C7Saturation
    
    public init(intensity: Float = 0.7) {
        self.intensity = intensity
        self.bilateralBlurFilter = C7BilateralBlur(distanceNormalizationFactor: 5.0, stepOffset: 4)
        self.exposureFilter = C7Exposure(exposure: 0.06)
        self.saturationFilter = C7Saturation(saturation: 1.0)
        super.init()
    }
    
    /// Prepare intermediate textures for the portrait enhancement filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
        // Apply skin smoothing using bilateral blur
        let blurDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try bilateralBlurFilter.applyAtTexture(form: currentTexture, to: blurDest, for: buffer)
        
        // Apply subtle exposure adjustment for face brightening
        let exposureDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try exposureFilter.applyAtTexture(form: currentTexture, to: exposureDest, for: buffer)
        
        // Apply subtle saturation adjustment
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

//
//  C7CombinationDreamy.swift
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

import Foundation

/// 梦幻风格组合滤镜
/// Dreamy style combination filter
public final class C7CombinationDreamy: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Blur strength, ranging from 0.0 to 1.0
    public var blurStrength: Float = 0.3 {
        didSet {
            blurStrength = max(0.0, min(1.0, blurStrength))
            gaussianBlurFilter.radius = blurStrength * 5.0
        }
    }
    
    /// Warmth adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var warmth: Float = 0.2
    
    /// Softness adjustment, ranging from 0.0 to 1.0
    public var softness: Float = 0.4
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationDreamy")
    }
    
    public override var factors: [Float] {
        return [intensity, warmth, softness]
    }
    
    public override var otherInputTextures: C7InputTextures {
        return intermediateTextures
    }
    
    private var gaussianBlurFilter: MPSGaussianBlur
    private var saturationFilter: C7Saturation
    private var exposureFilter: C7Exposure
    
    public init(intensity: Float = 1.0) {
        self.intensity = intensity
        self.gaussianBlurFilter = MPSGaussianBlur(radius: 1.5)
        self.saturationFilter = C7Saturation(saturation: 1.1)
        self.exposureFilter = C7Exposure(exposure: 0.1)
        super.init()
    }
    
    /// Prepare intermediate textures for the dreamy filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
        // Apply Gaussian blur for dreamy effect
        let blurDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try gaussianBlurFilter.applyAtTexture(form: currentTexture, to: blurDest, for: buffer)
        
        // Apply subtle saturation adjustment
        let saturationDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try saturationFilter.applyAtTexture(form: currentTexture, to: saturationDest, for: buffer)
        
        // Apply subtle exposure adjustment for brightness
        let exposureDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try exposureFilter.applyAtTexture(form: currentTexture, to: exposureDest, for: buffer)
        
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

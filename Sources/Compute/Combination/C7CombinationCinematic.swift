//
//  C7CombinationCinematic.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// 电影级色调组合滤镜
/// Cinematic tone combination filter
public final class C7CombinationCinematic: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Contrast adjustment, ranging from 0.0 to 2.0, with 1.0 being the original
    public var contrast: Float = 1.2 {
        didSet {
            contrastFilter.contrast = contrast
        }
    }
    
    /// Saturation adjustment, ranging from 0.0 to 2.0, with 1.0 being the original
    public var saturation: Float = 0.8 {
        didSet {
            saturationFilter.saturation = saturation
        }
    }
    
    /// Exposure adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    public var exposure: Float = 0.1 {
        didSet {
            exposureFilter.exposure = exposure
        }
    }
    
    /// Vignette intensity, ranging from 0.0 to 1.0
    public var vignetteIntensity: Float = 0.3 {
        didSet {
            // Convert intensity to start and end values for C7Vignette
            vignetteFilter.start = 0.3
            vignetteFilter.end = 0.3 + (0.75 - 0.3) * (1.0 - vignetteIntensity)
        }
    }
    
    /// Blur radius for subtle softening, ranging from 0.0 to 5.0
    public var blurRadius: Float = 0.5 {
        didSet {
            blurFilter.radius = blurRadius
        }
    }
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationCinematic")
    }
    
    public override var factors: [Float] {
        return [intensity]
    }
    
    public override var otherInputTextures: C7InputTextures {
        // Return the processed textures from intermediateTextures
        return intermediateTextures
    }
    
    private var contrastFilter: C7Contrast
    private var saturationFilter: C7Saturation
    private var exposureFilter: C7Exposure
    private var vignetteFilter: C7Vignette
    private var blurFilter: C7GaussianBlur
    
    public init(intensity: Float = 0.7) {
        self.intensity = intensity
        self.contrastFilter = C7Contrast(contrast: 1.2)
        self.saturationFilter = C7Saturation(saturation: 0.8)
        self.exposureFilter = C7Exposure(exposure: 0.1)
        self.vignetteFilter = C7Vignette(start: 0.3, end: 0.75, color: .zero)
        self.blurFilter = C7GaussianBlur(radius: 0.5)
        super.init()
    }
    
    /// Prepare intermediate textures for the cinematic filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        var currentTexture = source
        
        // Apply subtle blur first
        let blurDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try blurFilter.applyAtTexture(form: currentTexture, to: blurDest, for: buffer)
        
        // Apply color adjustments
        let colorDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try contrastFilter.applyAtTexture(form: currentTexture, to: colorDest, for: buffer)
        
        let saturationDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try saturationFilter.applyAtTexture(form: currentTexture, to: saturationDest, for: buffer)
        
        let exposureDest = try TextureLoader.copyTexture(with: source)
        currentTexture = try exposureFilter.applyAtTexture(form: currentTexture, to: exposureDest, for: buffer)
        
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

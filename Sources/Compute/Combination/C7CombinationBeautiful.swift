//
//  C7CombinationBeautiful.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation

public final class C7CombinationBeautiful: C7CombinationBase {
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var smoothDegree: Float = 0.0
    
    /// A normalization factor for the distance between central color and sample color, with a default of 8.0
    public var distanceNormalizationFactor: Float = 8 {
        didSet {
            blurFilter.distanceNormalizationFactor = distanceNormalizationFactor
        }
    }
    
    public var stepOffset: Float = 4 {
        didSet {
            blurFilter.stepOffset = stepOffset
        }
    }
    
    public var edgeStrength: Float = 1 {
        didSet {
            edgeFilter.edgeStrength = edgeStrength
        }
    }
    
    public override var modifier: ModifierEnum {
        return .compute(kernel: "C7CombinationBeautiful")
    }
    
    public override var factors: [Float] {
        return [intensity, smoothDegree]
    }
    
    public override var otherInputTextures: C7InputTextures {
        // Return the first two textures from intermediateTextures
        // These should be the blur and edge textures
        return Array(intermediateTextures.prefix(2))
    }
    
    private var blurFilter: C7BilateralBlur
    private var edgeFilter: C7Sobel
    
    public init(smoothDegree: Float = 0.0) {
        self.smoothDegree = smoothDegree
        self.blurFilter = C7BilateralBlur(distanceNormalizationFactor: 8, stepOffset: 4)
        self.edgeFilter = C7Sobel(edgeStrength: 1.0)
        super.init()
    }
    
    /// Prepare intermediate textures for the beautiful filter
    public override func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        let destTexture = try TextureLoader.copyTexture(with: source)
        
        // Apply blur filter
        let blurTexture = try blurFilter.applyAtTexture(form: source, to: destTexture, for: buffer)
        intermediateTextures.append(blurTexture)
        
        // Apply edge filter
        let edgeDestTexture = try TextureLoader.copyTexture(with: source)
        let edgeTexture = try edgeFilter.applyAtTexture(form: source, to: edgeDestTexture, for: buffer)
        intermediateTextures.append(edgeTexture)
        
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

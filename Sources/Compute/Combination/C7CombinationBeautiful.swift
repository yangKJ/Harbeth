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
    
    /// 空间域标准差，控制模糊范围，默认值为10.0
    public var sigmaSpace: Float = 10.0 {
        didSet {
            blurFilter.sigmaSpace = sigmaSpace
        }
    }
    
    /// 颜色域标准差，控制颜色相似性阈值，默认值为0.1
    public var sigmaColor: Float = 0.1 {
        didSet {
            blurFilter.sigmaColor = sigmaColor
        }
    }
    
    /// 模糊半径，控制采样范围，默认值为5
    public var radius: Float = 5 {
        didSet {
            blurFilter.radius = radius
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
    
    public init(smoothDegree: Float = 0.0, intensity: Float = 1.0) {
        self.intensity = intensity
        self.smoothDegree = smoothDegree
        self.blurFilter = C7BilateralBlur(sigmaSpace: 15.0, sigmaColor: 0.3, radius: 7)
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

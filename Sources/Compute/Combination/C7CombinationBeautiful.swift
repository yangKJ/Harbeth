//
//  C7CombinationBeautiful.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation

public class C7CombinationBeautiful: C7FilterProtocol, CombinationProtocol {
    
    @ZeroOneRange public var intensity: Float = R.iRange.value
    
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
    
    public var modifier: Modifier {
        return .compute(kernel: "C7CombinationBeautiful")
    }
    
    public var factors: [Float] {
        return [intensity, smoothDegree]
    }
    
    public var otherInputTextures: C7InputTextures {
        [blurTexture, edgeTexture]
    }
    
    private var blurTexture: MTLTexture!
    private var edgeTexture: MTLTexture!
    
    private var blurFilter: C7CombinationBilateralBlur
    private var edgeFilter: C7Sobel
    
    public init(smoothDegree: Float = 0.0) {
        self.smoothDegree = smoothDegree
        self.blurFilter = C7CombinationBilateralBlur(distanceNormalizationFactor: 8, stepOffset: 4)
        self.edgeFilter = C7Sobel(edgeStrength: 1.0)
    }
    
    public func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        let destTexture = try TextureLoader.copyTexture(with: texture2)
        self.blurTexture = try blurFilter.applyAtTexture(form: texture, to: destTexture, for: buffer)
        self.edgeTexture = try edgeFilter.applyAtTexture(form: texture, to: destTexture, for: buffer)
        return texture
    }
}

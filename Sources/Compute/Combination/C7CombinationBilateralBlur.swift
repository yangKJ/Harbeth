//
//  C7CombinationBilateralBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

/// 双边模糊
/// A bilateral blur, which tries to blur similar color values while preserving sharp edges
public struct C7CombinationBilateralBlur: C7FilterProtocol, CombinationProtocol {
    
    /// A normalization factor for the distance between central color and sample color, with a default of 8.0
    public var distanceNormalizationFactor: Float = 8 {
        didSet {
            firstBlur.radius = distanceNormalizationFactor
        }
    }
    
    public var stepOffset: Float = 0 {
        didSet {
            firstBlur.offect = C7Point2D(x: stepOffset, y: 0)
        }
    }
    
    public var modifier: Modifier {
        return .compute(kernel: "C7BilateralBlur")
    }
    
    public var factors: [Float] {
        return [distanceNormalizationFactor, 0, stepOffset]
    }
    
    private var firstBlur: C7BilateralBlur
    
    public init(distanceNormalizationFactor: Float = 8, stepOffset: Float = 0) {
        self.distanceNormalizationFactor = distanceNormalizationFactor
        self.stepOffset = stepOffset
        self.firstBlur = C7BilateralBlur()
        self.firstBlur.radius = distanceNormalizationFactor
        self.firstBlur.offect = C7Point2D(x: stepOffset, y: 0)
    }
    
    public func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        let destTexture = try Texturior.copyTexture(with: texture2)
        try firstBlur.applyAtTexture(form: texture, to: texture2, commandBuffer: buffer)
        return destTexture
    }
}

//
//  C7BilateralBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

import Foundation

/// 双边模糊
/// A bilateral blur, which tries to blur similar color values while preserving sharp edges
public struct C7BilateralBlur: C7FilterProtocol {
    
    /// A normalization factor for the distance between central color and sample color, with a default of 8.0
    public var distanceNormalizationFactor: Float = 8
    
    /// Step offset for the blur calculation
    public var stepOffset: Float = 0
    
    /// Radius for the blur effect
    public var radius: Float = 8 {
        didSet {
            distanceNormalizationFactor = radius
        }
    }
    
    /// Offset for the blur calculation
    public var offect: C7Point2D = .zero {
        didSet {
            stepOffset = offect.x
        }
    }
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7BilateralBlur")
    }
    
    public var factors: [Float] {
        return [distanceNormalizationFactor, 0, stepOffset]
    }
    
    public init(distanceNormalizationFactor: Float = 8, stepOffset: Float = 0) {
        self.distanceNormalizationFactor = distanceNormalizationFactor
        self.stepOffset = stepOffset
        self.radius = distanceNormalizationFactor
        self.offect = C7Point2D(x: stepOffset, y: 0)
    }
    
    public init(radius: Float = 8) {
        self.init(distanceNormalizationFactor: radius, stepOffset: 0)
    }
}

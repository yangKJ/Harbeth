//
//  C7SphereRefraction.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

public struct C7SphereRefraction: C7FilterProtocol {
    
    public var radius: Float = 0.25
    public var refractiveIndex: Float = 0.71
    public var aspectRatio: Float = 1
    public var center: C7Point2D = C7Point2D.center
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7SphereRefraction")
    }
    
    public var factors: [Float] {
        return [radius.isFinite ? max(radius, 0) : 0, refractiveIndex.isFinite ? refractiveIndex : 0.71,
                aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1,
                center.x.isFinite ? center.x : 0.5, center.y.isFinite ? center.y : 0.5]
    }
    
    public var samplingFootprint: SamplingFootprint { .global }

    public var kernelPixelContract: KernelPixelContract {
        .init(precision: .float32, samplingFootprint: .global, coordinateDependency: .fullImage,
              globalDependency: .imageDimensions, fusionPolicy: .disabled)
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public init(radius: Float = 0.25, refractiveIndex: Float = 0.71, aspectRatio: Float = 1) {
        self.radius = radius
        self.refractiveIndex = refractiveIndex
        self.aspectRatio = aspectRatio
    }
}

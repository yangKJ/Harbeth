//
//  C7Halftone.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Halftone: C7FilterProtocol {
    
    /// How large the halftone dots are, as a fraction of the width of the image, default of 0.01
    public var fractionalWidth: Float = 0.01
    
    public var samplingFootprint: SamplingFootprint { .global }
    public var kernelPixelContract: KernelPixelContract {
        .init(precision: .float32, samplingFootprint: .global, coordinateDependency: .fullImage,
              globalDependency: .imageDimensions, fusionPolicy: .disabled)
    }

    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Halftone")
    }
    
    public var factors: [Float] {
        return [fractionalWidth.isFinite && fractionalWidth > 0 ? fractionalWidth : 0]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public init(fractionalWidth: Float = 0.01) {
        self.fractionalWidth = fractionalWidth
    }
}

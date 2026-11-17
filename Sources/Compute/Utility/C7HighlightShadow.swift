//
//  C7HighlightShadow.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 高光阴影
public struct C7HighlightShadow: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    /// Increase to lighten shadows, from 0.0 to 1.0, with 0.0 as the default.
    @ZeroOneRange public var shadows: Float = range.value
    
    /// Decrease to darken highlights, from 1.0 to 0.0, with 1.0 as the default.
    @ZeroOneRange public var highlights: Float = 1
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7HighlightShadow")
    }
    
    public var factors: [Float] {
        return [shadows.isFinite ? shadows : 0, highlights.isFinite ? highlights : 1]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, precision: .float32,
              dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: .point)
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }

    public init(highlights: Float = 1, shadows: Float = range.value) {
        self.highlights = highlights
        self.shadows = shadows
    }
}

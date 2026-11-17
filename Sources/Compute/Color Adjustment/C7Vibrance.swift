//
//  C7Vibrance.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 自然饱和度
public struct C7Vibrance: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.2, max: 1.2, value: 0.0)
    
    /// Change the vibrance of an image, from -1.2 to 1.2, with a default of 0.0
    public var vibrance: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Vibrance")
    }
    
    public var factors: [Float] {
        return [vibrance.isFinite ? vibrance : 0]
    }
    
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, outputAlpha: .preserveInput, precision: .float32, samplingFootprint: .point)
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }

    public init(vibrance: Float = range.value) {
        self.vibrance = vibrance
    }
}

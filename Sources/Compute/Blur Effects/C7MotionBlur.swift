//
//  C7MotionBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/2/14.
//

import Foundation

/// 移动模糊
public struct C7MotionBlur: C7FilterProtocol {
    
    /// A multiplier for the blur size
    public var radius: Float = 0
    
    /// The angular direction of the blur, in degrees, with a default of 0.0
    public var blurAngle: Float = 0
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7MotionBlur")
    }
    
    public var factors: [Float] {
        return [radius.isFinite ? abs(radius) : 0, blurAngle.isFinite ? blurAngle.truncatingRemainder(dividingBy: 360) : 0]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    /// 采样距离依赖完整画布尺寸；区域执行器必须解析实际ROI。
    public var samplingFootprint: SamplingFootprint {
        .dynamic
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .dynamic,
            coordinateDependency: .fullImage,
            globalDependency: .imageDimensions,
            fusionPolicy: .disabled
        )
    }

    public init(radius: Float = 0, blurAngle: Float = 0) {
        self.radius = radius
        self.blurAngle = blurAngle
    }
}

//
//  C7ZoomBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/2/10.
//

import Foundation

/// 缩放模糊效果
/// See: https://support.apple.com/en-in/guide/motion/motn169fc244/mac
public struct C7ZoomBlur: C7FilterProtocol {
    
    /// A multiplier for the blur size, ranging from 0.0 on up, with a default of 0.0
    /// Sets the radius of the blur. Drag the small circle (above the Center onscreen control) in the canvas to adjust the blur amount.
    public var radius: Float = 0
    
    /// Sets the position of the center of the blur. Drag the Center onscreen control in the canvas to adjust the center position.
    public var blurCenter: C7Point2D = C7Point2D.center
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ZoomBlur")
    }
    
    public var factors: [Float] {
        return [blurCenter.x, blurCenter.y, radius.isFinite ? abs(radius) : 0]
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

    public init(radius: Float = 0) {
        self.radius = radius
    }
}

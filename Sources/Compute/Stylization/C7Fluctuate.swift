//
//  C7Fluctuate.swift
//  Harbeth
//
//  Created by Condy on 2022/11/30.
//

import Foundation

/// 波动效果，类似于波纹效果
/// The fluctuation effect is similar to the ripple effect
public struct C7Fluctuate: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.5)
    
    /// 控制波动的频率，值越大波动越密集
    /// Control the frequency of fluctuations. The larger the value, the more dense the fluctuations.
    public var frequency: Float = 10.0
    
    /// 控制振幅的大小，越大图像越夸张
    /// Control the size of the amplitude. The larger the image, the more exaggerated the image.
    public var amplitude: Float = 0.05
    
    /// 控制波动的强度，0.0 到 1.0
    /// Control the intensity of fluctuation, 0.0 to 1.0
    @ZeroOneRange public var fluctuate: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Fluctuate")
    }
    
    public var factors: [Float] {
        return [frequency, amplitude, fluctuate]
    }
    
    public init(frequency: Float = 10.0, amplitude: Float = 0.05, fluctuate: Float = range.value) {
        self.frequency = frequency
        self.amplitude = amplitude
        self.fluctuate = fluctuate
    }
}

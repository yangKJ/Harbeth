//
//  C7Fluctuate.swift
//  Harbeth
//
//  Created by Condy on 2022/11/30.
//

import Foundation

/// 波动效果，还可类似涂鸦效果
public struct C7Fluctuate: C7FilterProtocol {
    
    /// 控制振幅的大小，越大图像越夸张
    /// Control the size of the amplitude, the larger the image, the more exaggerated the image.
    public var amplitude: Float = 0.002
    public var extent: Float = 50.0
    public var fluctuate: Float = 0.5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Fluctuate")
    }
    
    public var factors: [Float] {
        return [extent, amplitude, fluctuate]
    }
    
    public init(extent: Float = 50.0, amplitude: Float = 0.002, fluctuate: Float = 0.5) {
        self.extent = extent
        self.amplitude = amplitude
        self.fluctuate = fluctuate
    }
}

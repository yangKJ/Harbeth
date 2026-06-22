//
//  C7Vignette.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

/// 渐晕效果，使边缘的图像淡化
public struct C7Vignette: C7FilterProtocol {
    
    /// The normalized distance from the center where the vignette effect starts, with a default of 0.3
    public var start: Float = 0.3
    /// The normalized distance from the center where the vignette effect ends, with a default of 0.75
    public var end: Float = 0.75
    public var center: C7Point2D = C7Point2D.center
    /// Keep the color scheme
    public var color: C7Color = .zero
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Vignette")
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "centerX", index: 0, stage: .compute, value: .float(center.x)),
            KernelParameterBinding(name: "centerY", index: 1, stage: .compute, value: .float(center.y)),
            KernelParameterBinding(name: "start", index: 2, stage: .compute, value: .float(start)),
            KernelParameterBinding(name: "end", index: 3, stage: .compute, value: .float(end)),
            KernelParameterBinding(name: "color", index: 4, stage: .compute, value: .float3(Vector3(color: color).to_factor()))
        ]
    }
    
    public init(start: Float = 0.3, end: Float = 0.75, color: C7Color = .zero) {
        self.start = start
        self.end = end
        self.color = color
    }
    
    public init(vignette: Float) {
        self.start = vignette
        self.end = vignette * 2.5
        self.color = .zero
    }
}

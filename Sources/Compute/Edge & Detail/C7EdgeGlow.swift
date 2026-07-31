//
//  C7EdgeGlow.swift
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

import Foundation

public struct C7EdgeGlow: C7FilterProtocol {
    
    /// The adjusted time, from 0.0 to 1.0, with a default of 0.5
    public var time: Float = 0.5
    /// The edge span is larger than this. form 0.0 to 1.0
    public var spacing: Float = 0.5
    
    public var lineColor: C7Color = C7Color.green
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7EdgeGlow")
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "time", index: 0, stage: .compute, value: .float(time)),
            KernelParameterBinding(name: "spacing", index: 1, stage: .compute, value: .float(spacing)),
            KernelParameterBinding(name: "lineColor", index: 2, stage: .compute, value: .float4(lineColor.c7.toSIMD4()))
        ]
    }
    
    public init(time: Float = 0.5, spacing: Float = 0.5, lineColor: C7Color = .green) {
        self.time = time
        self.spacing = spacing
        self.lineColor = lineColor
    }
}

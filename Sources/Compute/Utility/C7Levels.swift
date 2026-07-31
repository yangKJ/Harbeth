//
//  C7Levels.swift
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

import Foundation

/// 色阶
public struct C7Levels: C7FilterProtocol {
    
    public var minimum: C7Color = C7Color.black
    public var middle:  C7Color = C7Color.white
    public var maximum: C7Color = C7Color.white
    public var minOutput: C7Color = C7Color.black
    public var maxOutput: C7Color = C7Color.white
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7LevelsFilter")
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "minimum", index: 0, stage: .compute, value: .float3(minimum.c7.toSIMD3())),
            KernelParameterBinding(name: "middle", index: 1, stage: .compute, value: .float3(middle.c7.toSIMD3())),
            KernelParameterBinding(name: "maximum", index: 2, stage: .compute, value: .float3(maximum.c7.toSIMD3())),
            KernelParameterBinding(name: "minOutput", index: 3, stage: .compute, value: .float3(minOutput.c7.toSIMD3())),
            KernelParameterBinding(name: "maxOutput", index: 4, stage: .compute, value: .float3(maxOutput.c7.toSIMD3()))
        ]
    }
    
    public init(minimum: C7Color = .black, middle: C7Color = .white, maximum: C7Color = .white, minOutput: C7Color = .black, maxOutput: C7Color = .white) {
        self.minimum = minimum
        self.middle = middle
        self.maximum = maximum
        self.minOutput = minOutput
        self.maxOutput = maxOutput
    }
}

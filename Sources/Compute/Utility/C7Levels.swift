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

    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, outputAlpha: .preserveInput, precision: .float32,
              dynamicRangeBehavior: .clampsToUnitRange, samplingFootprint: .point)
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }
    public var kernelParameterBindings: [KernelParameterBinding] {
        LevelsParameters(inputBlack: minimum.c7.toSIMD3(), gamma: middle.c7.toSIMD3(), inputWhite: maximum.c7.toSIMD3(),
                         outputBlack: minOutput.c7.toSIMD3(), outputWhite: maxOutput.c7.toSIMD3())
            .bindings(names: ["minimum", "middle", "maximum", "minOutput", "maxOutput"])
    }

    public init(minimum: C7Color = .black, middle: C7Color = .white, maximum: C7Color = .white, minOutput: C7Color = .black, maxOutput: C7Color = .white) {
        self.minimum = minimum
        self.middle = middle
        self.maximum = maximum
        self.minOutput = minOutput
        self.maxOutput = maxOutput
    }
}

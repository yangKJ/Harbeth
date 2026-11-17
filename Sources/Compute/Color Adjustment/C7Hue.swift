//
//  C7Hue.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation

public struct C7Hue: C7FilterProtocol {
    
    /// Hue adjustment, unit is degree
    @DegreeRange public var hue: Float = 90.0
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Hue")
    }
    
    public var factors: [Float] {
        let radians = Degree(value: hue.isFinite ? hue : 0).radians
        return [radians, cos(radians), sin(radians)]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public var kernelPixelContract: KernelPixelContract {
        .init(precision: .float32, dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: .point)
    }

    public init(hue: Float = 90.0) {
        self.hue = hue
    }
}

//
//  C7DepthLuminance.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7DepthLuminance: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.1, max: 2.0, value: 1.0)
    
    public var offset: Float = 0.0
    @Clamping(range.min...range.max) public var depthRange: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7DepthLuminance")
    }
    
    public var factors: [Float] {
        return [offset, depthRange]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public init(offset: Float = 0.0, depthRange: Float = range.value) {
        self.offset = offset
        self.depthRange = depthRange
    }
}

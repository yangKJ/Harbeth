//
//  C7Kuwahara.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Kuwahara: C7FilterProtocol {
    
    public static let range: ParameterRange<Int, Self> = .init(min: 1, max: 8, value: 3)
    
    /// The radius to sample from when creating the brush-stroke effect, with a default of 3.
    /// The larger the radius, the slower the filter.
    @Clamping(range.min...range.max) public var radius: Int = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Kuwahara")
    }
    
    public var factors: [Float] {
        return [Float(radius)]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public init(radius: Int = range.value) {
        self.radius = radius
    }
}

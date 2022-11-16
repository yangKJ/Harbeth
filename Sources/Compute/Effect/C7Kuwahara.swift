//
//  C7Kuwahara.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Kuwahara: C7FilterProtocol {
    
    /// The radius to sample from when creating the brush-stroke effect, with a default of 3.
    /// The larger the radius, the slower the filter.
    public var radius: Int = 3
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Kuwahara")
    }
    
    public var factors: [Float] {
        return [Float(radius)]
    }
    
    public init(radius: Int = 3) {
        self.radius = radius
    }
}

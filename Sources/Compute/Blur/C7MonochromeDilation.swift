//
//  C7MonochromeDilation.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// Monochrome blur effect, single channel expansion
public struct C7MonochromeDilation: C7FilterProtocol {
    
    /// Radius in pixel, with a default of 0.0
    public var pixelRadius: Int = 0
    
    public var vertical: Bool = false
    
    public var modifier: Modifier {
        return .compute(kernel: "C7MonochromeDilation")
    }
    
    public var factors: [Float] {
        return [Float(pixelRadius), vertical ? 1 : 0]
    }
    
    public init(pixelRadius: Int = 0) {
        self.pixelRadius = pixelRadius
    }
}

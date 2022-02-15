//
//  C7SobelEdgeDetection.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7SobelEdgeDetection: C7FilterProtocol {
    
    /// Adjusts the dynamic range of the filter. default is 1.0
    /// Higher values lead to stronger edges, but can saturate the intensity colorspace.
    public var edgeStrength: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7SobelEdgeDetection")
    }
    
    public var factors: [Float] {
        return [edgeStrength]
    }
    
    public init() { }
}

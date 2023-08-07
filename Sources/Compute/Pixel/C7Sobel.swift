//
//  C7Sobel.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// 特征提取，基于Sobel算子
/// Feature extraction, based on Sobel operator
public struct C7Sobel: C7FilterProtocol {
    
    /// Adjusts the dynamic range of the filter. default is 1.0
    /// Higher values lead to stronger edges, but can saturate the intensity colorspace.
    public var edgeStrength: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Sobel")
    }
    
    public var factors: [Float] {
        return [edgeStrength]
    }
    
    public init(edgeStrength: Float = 1.0) {
        self.edgeStrength = edgeStrength
    }
}

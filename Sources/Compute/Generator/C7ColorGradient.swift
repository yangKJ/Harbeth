//
//  C7ColorGradient.swift
//  Harbeth
//
//  Created by Condy on 2023/7/27.
//

import Foundation

/// 常见渐变色滤镜
public struct C7ColorGradient: C7FilterProtocol {
    
    public enum GradientType {
        case rgUV
        case rgUVB1
        case radial
    }
    
    /// There is no need to create a new output texture, just use the input texture.
    public var needCreateDestTexture: Bool = false
    
    public var modifier: Modifier {
        return .compute(kernel: type.kernel)
    }
    
    let type: GradientType
    
    public init(with type: GradientType) {
        self.type = type
    }
}

extension C7ColorGradient.GradientType {
    public var kernel: String {
        switch self {
        case .rgUV:
            return "C7RGUVGradient"
        case .rgUVB1:
            return "C7RGUVB1Gradient"
        case .radial:
            return "C7RadialGradient"
        }
    }
}

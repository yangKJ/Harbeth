//
//  C7SolidColor.swift
//  Harbeth
//
//  Created by Condy on 2022/10/10.
//

import Foundation

/// 纯色滤镜
public struct C7SolidColor: C7FilterProtocol, ComputeFiltering {
    
    public var color: C7Color = .white
    
    public var modifier: Modifier {
        return .compute(kernel: "C7SolidColor")
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = Vector4.init(color: color).to_factor()
        computeEncoder.setBytes(&factor, length: Vector4.size, index: index + 1)
    }
    
    public init(color: C7Color = .white) {
        self.color = color
    }
}

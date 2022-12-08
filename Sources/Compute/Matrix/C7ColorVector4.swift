//
//  C7ColorVector4.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// 四维向量颜色
public struct C7ColorVector4: C7FilterProtocol, ComputeFiltering {
    
    public var vector: Vector4
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorVector4")
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = vector.to_factor()
        computeEncoder.setBytes(&factor, length: Vector4.size, index: index + 1)
    }
    
    public init(vector: Vector4) {
        self.vector = vector
    }
}

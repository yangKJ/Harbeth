//
//  C7ColorMatrix4x5.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// 4 x 5 color matrix.
public struct C7ColorMatrix4x5: C7FilterProtocol, ComputeFiltering {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    /// The degree to which the new transformed color replaces the original color for each pixel, default 1
    @ZeroOneRange public var intensity: Float = range.value
    public var matrix: Matrix4x5
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorMatrix4x5")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = matrix.matrix4x4.to_factor()
        computeEncoder.setBytes(&factor, length: Matrix4x4.size, index: index + 1)
        var factor2 = matrix.vector4.to_factor()
        computeEncoder.setBytes(&factor2, length: Vector4.size, index: index + 2)
    }
    
    public init(matrix: Matrix4x5) {
        self.matrix = matrix
    }
}

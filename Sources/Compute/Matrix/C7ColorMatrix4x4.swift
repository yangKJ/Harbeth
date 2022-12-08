//
//  C7ColorMatrix4x4.swift
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

import Foundation

/// 4x4 color matrix.
public struct C7ColorMatrix4x4: C7FilterProtocol, ComputeFiltering {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    /// The degree to which the new transformed color replaces the original color for each pixel, default 1
    @ZeroOneRange public var intensity: Float = range.value
    /// Color offset for each channel.
    public var offset: RGBAColor = .zero
    public var matrix: Matrix4x4
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorMatrix4x4")
    }
    
    public var factors: [Float] {
        return [intensity] + offset.toFloatArray()
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = matrix.to_factor()
        computeEncoder.setBytes(&factor, length: Matrix4x4.size, index: index + 1)
    }
    
    public init(matrix: Matrix4x4) {
        self.matrix = matrix
    }
}

//
//  C7ColorMatrix4x4.swift
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

import Foundation

/// 4x4 color matrix.
public struct C7ColorMatrix4x4: C7FilterProtocol {
    
    /// The degree to which the new transformed color replaces the original color for each pixel, default 1
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    /// Color offset for each channel.
    public var offset: Vector4 = .zero
    public var matrix: Matrix4x4
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorMatrix4x4")
    }
    
    public var factors: [Float] {
        return [intensity] + offset.values
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = matrix.to_factor()
        computeEncoder.setBytes(&factor, length: Matrix4x4.size, index: index)
    }
    
    public init(matrix: Matrix4x4, offset: Vector4 = .zero, intensity: Float = 1.0) {
        self.matrix = matrix
        self.offset = offset
        self.intensity = intensity
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
    
    public func updateMatrix4x4(_ matrix: Matrix4x4) -> Self {
        var copy = self
        copy.matrix = matrix
        return copy
    }
    
    public func updateOffset(_ offset: Vector4) -> Self {
        var copy = self
        copy.offset = offset
        return copy
    }
}

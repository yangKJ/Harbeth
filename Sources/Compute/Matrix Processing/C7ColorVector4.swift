//
//  C7ColorVector4.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// 四维向量颜色
public struct C7ColorVector4: C7FilterProtocol {
    
    /// The degree to which the new transformed color replaces the original color for each pixel, default 1
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var vector: Vector4
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorVector4")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = vector.to_factor()
        computeEncoder.setBytes(&factor, length: Vector4.size, index: index)
    }
    
    public init(vector: Vector4, intensity: Float = 1.0) {
        self.vector = vector
        self.intensity = intensity
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
    
    public func updateVector4(_ vector: Vector4) -> Self {
        var copy = self
        copy.vector = vector
        return copy
    }
}

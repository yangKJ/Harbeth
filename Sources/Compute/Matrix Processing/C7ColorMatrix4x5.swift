//
//  C7ColorMatrix4x5.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// 4 x 5 color matrix.
public struct C7ColorMatrix4x5: C7FilterProtocol {
    
    /// The degree to which the new transformed color replaces the original color for each pixel, default 1
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var matrix: Matrix4x5
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorMatrix4x5")
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "intensity", index: 0, stage: .compute, value: .float(intensity)),
            KernelParameterBinding(name: "matrix", index: 1, stage: .compute, value: .matrix4x4(matrix.matrix4x4)),
            KernelParameterBinding(name: "offset", index: 2, stage: .compute, value: .float4(matrix.vector4.to_factor()))
        ]
    }
    
    public init(matrix: Matrix4x5, intensity: Float = 1.0) {
        self.matrix = matrix
        self.intensity = intensity
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
    
    public func updateMatrix4x5(_ matrix: Matrix4x5) -> Self {
        var copy = self
        copy.matrix = matrix
        return copy
    }
}

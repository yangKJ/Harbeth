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
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "intensity", index: 0, stage: .compute, value: .float(intensity)),
            KernelParameterBinding(name: "offsetR", index: 1, stage: .compute, value: .float(offset.values[0])),
            KernelParameterBinding(name: "offsetG", index: 2, stage: .compute, value: .float(offset.values[1])),
            KernelParameterBinding(name: "offsetB", index: 3, stage: .compute, value: .float(offset.values[2])),
            KernelParameterBinding(name: "offsetA", index: 4, stage: .compute, value: .float(offset.values[3])),
            KernelParameterBinding(name: "matrix", index: 5, stage: .compute, value: .matrix4x4(matrix))
        ]
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

//
//  C7ChromaKey.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 祛除某种色系，有点类似绿幕抠图，被祛除的像素会变透明
/// Remove a certain color system, a bit like green screen matting, The removed pixels become transparent
public struct C7ChromaKey: C7FilterProtocol, ComputeFiltering {
    
    /// How close a color match needs to exist to the target color to be replaced (default of 0.4)
    public var thresholdSensitivity: Float = 0.4
    /// How smoothly to blend for the color match (default of 0.1)
    public var smoothing: Float = 0.1
    /// Color patches that need to be removed,
    public var color: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ChromaKey")
    }
    
    public var factors: [Float] {
        return [thresholdSensitivity, smoothing]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = Vector3.init(color: color).to_factor()
        computeEncoder.setBytes(&factor, length: Vector3.size, index: index + 1)
    }
    
    public init(thresholdSensitivity: Float = 0.4, smoothing: Float = 0.1, color: C7Color = .zero) {
        self.thresholdSensitivity = thresholdSensitivity
        self.smoothing = smoothing
        self.color = color
    }
}

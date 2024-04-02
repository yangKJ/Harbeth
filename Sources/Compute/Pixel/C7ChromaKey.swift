//
//  C7ChromaKey.swift
//  Harbeth
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 祛除某种色系，有点类似绿幕抠图，被祛除的像素会变透明
/// Remove the background that has the specified a color. A bit like green screen matting, The removed pixels become transparent.
public struct C7ChromaKey: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.1)
    
    /// How close a color match needs to exist to the target color to be replaced, default of 0.4
    @ZeroOneRange public var thresholdSensitivity: Float = 0.4
    /// How smoothly to blend for the color match, default of 0.1
    @ZeroOneRange public var smoothing: Float = range.value
    /// Remove the background that has the specified a color. Remove green by default.
    public var chroma: C7Color = .green
    /// The color to be replaced in chroma color, subtract a color scheme and replace it later.
    /// If the alpha is 0, it will not be replaced.
    public var replace: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ChromaKey")
    }
    
    public var factors: [Float] {
        return [thresholdSensitivity, smoothing]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var chromaFactor = Vector3.init(color: chroma).to_factor()
        computeEncoder.setBytes(&chromaFactor, length: Vector3.size, index: index + 1)
        var replaceFactor = Vector4(color: replace).to_factor()
        computeEncoder.setBytes(&replaceFactor, length: Vector4.size, index: index + 2)
    }
    
    public init(thresholdSensitivity: Float = 0.4,
                smoothing: Float = range.value,
                chroma: C7Color = .zero,
                replace: C7Color = .zero) {
        self.thresholdSensitivity = thresholdSensitivity
        self.smoothing = smoothing
        self.chroma = chroma
        self.replace = replace
    }
}

//
//  C7ReplaceRGBA.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 先扣掉某种色系，然后再替换
/// Subtract a color scheme and replace it later
public struct C7ReplaceRGBA: C7FilterProtocol, ComputeFiltering {
    
    /// How close a color match needs to exist to the target color to be replaced (default of 0.4)
    public var thresholdSensitivity: Float = 0.4
    /// How smoothly to blend for the color match (default of 0.1)
    public var smoothing: Float = 0.1
    /// Need to be transparent color
    public var chroma: C7Color = .zero
    /// The color to be replaced
    public var replaceColor: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ReplaceRGBA")
    }
    
    public var factors: [Float] {
        return [thresholdSensitivity, smoothing]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var chromaFactor = Vector3.init(color: chroma).to_factor()
        computeEncoder.setBytes(&chromaFactor, length: Vector3.size, index: index + 1)
        var replaceColorFactor = Vector4(color: replaceColor).to_factor()
        computeEncoder.setBytes(&replaceColorFactor, length: Vector4.size, index: index + 2)
    }
    
    public init(thresholdSensitivity: Float = 0.4,
                smoothing: Float = 0.1,
                chroma: C7Color = .zero,
                replaceColor: C7Color = .zero) {
        self.thresholdSensitivity = thresholdSensitivity
        self.smoothing = smoothing
        self.chroma = chroma
        self.replaceColor = replaceColor
    }
}

//
//  C7HighlightShadowTint.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7HighlightShadowTint: C7FilterProtocol, ComputeFiltering {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    /// Increase to lighten shadows, from 0.0 to 1.0, with 0.0 as the default.
    @ZeroOneRange public var shadows: Float = range.value
    public var shadowsColor: C7Color = .zero
    
    /// Decrease to darken highlights, from 1.0 to 0.0, with 0.0 as the default.
    @ZeroOneRange public var highlights: Float = range.value
    public var highlightsColor: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7HighlightShadowTint")
    }
    
    public var factors: [Float] {
        return [shadows, highlights]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var shadowsFactor = Vector3.init(color: shadowsColor).to_factor()
        computeEncoder.setBytes(&shadowsFactor, length: Vector3.size, index: index + 1)
        var highlightsFactor = Vector3(color: highlightsColor).to_factor()
        computeEncoder.setBytes(&highlightsFactor, length: Vector3.size, index: index + 2)
    }
    
    public init(highlights: Float = range.value,
                highlightsColor: C7Color = .zero,
                shadows: Float = range.value,
                shadowsColor: C7Color = .zero) {
        self.highlights = highlights
        self.shadows = shadows
        self.highlightsColor = highlightsColor
        self.shadowsColor = shadowsColor
    }
}

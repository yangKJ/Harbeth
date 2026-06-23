//
//  C7CombinationCreativeAtmosphere.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

public final class C7CombinationCreativeAtmosphere: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var atmosphereType: Int = 0
    public var glowIntensity: Float = 0.3
    public var colorShift: Float = 0.2
    public var vignetteIntensity: Float = 0.4
    public var contrast: Float = 1.0

    public var pipelineFilters: [C7FilterProtocol] {
        let vignetteEnd = 0.3 + (0.8 - 0.3) * (1.0 - vignetteIntensity)
        return [
            MPSGaussianBlur(radius: glowIntensity * 3.0),
            C7Contrast(contrast: contrast),
            C7Vignette(start: 0.3, end: vignetteEnd, color: .zero)
        ]
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7CombinationBlendIntensity"),
            factors: [intensity, Float(atmosphereType), colorShift],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

//
//  C7CombinationVintage.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

public final class C7CombinationVintage: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var sepiaIntensity: Float = 0.8
    public var vignetteIntensity: Float = 0.6
    public var contrast: Float = 0.9
    public var saturation: Float = 0.7
    public var grainIntensity: Float = 0.4
    public var dustIntensity: Float = 0.2

    public var pipelineFilters: [C7FilterProtocol] {
        let vignetteEnd = 0.2 + (0.8 - 0.2) * (1.0 - vignetteIntensity)
        return [
            C7Sepia(intensity: sepiaIntensity),
            C7Contrast(contrast: contrast),
            C7Saturation(saturation: saturation),
            C7Granularity(grain: grainIntensity),
            C7Vignette(start: 0.2, end: vignetteEnd, color: .zero)
        ]
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7CombinationVintage"),
            factors: [intensity, dustIntensity],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

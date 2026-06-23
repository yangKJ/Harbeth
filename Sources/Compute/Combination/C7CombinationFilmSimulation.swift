//
//  C7CombinationFilmSimulation.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

public final class C7CombinationFilmSimulation: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var filmType: Int = 0
    public var grainIntensity: Float = 0.3
    public var contrast: Float = 1.1
    public var saturation: Float = 1.05
    public var vignetteIntensity: Float = 0.2

    public var pipelineFilters: [C7FilterProtocol] {
        let vignetteEnd = 0.4 + (0.9 - 0.4) * (1.0 - vignetteIntensity)
        return [
            C7Contrast(contrast: contrast),
            C7Saturation(saturation: saturation),
            C7Granularity(grain: grainIntensity),
            C7Vignette(start: 0.4, end: vignetteEnd, color: .zero)
        ]
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7CombinationBlendIntensity"),
            factors: [intensity, Float(filmType)],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

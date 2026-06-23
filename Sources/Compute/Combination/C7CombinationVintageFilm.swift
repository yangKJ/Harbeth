//
//  C7CombinationVintageFilm.swift
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

import Foundation

public final class C7CombinationVintageFilm: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var grainIntensity: Float = 0.6
    public var vignette: Float = 0.4
    public var sepiaTone: Float = 0.8

    public var pipelineFilters: [C7FilterProtocol] {
        [
            C7Sepia(intensity: sepiaTone),
            C7Contrast(contrast: 1.2),
            C7Saturation(saturation: 0.8)
        ]
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7CombinationVintageFilm"),
            factors: [intensity, grainIntensity, vignette, sepiaTone],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

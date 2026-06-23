//
//  C7CombinationCinematic.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

public final class C7CombinationCinematic: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var contrast: Float = 1.2
    public var saturation: Float = 0.8
    public var exposure: Float = 0.1
    public var vignetteIntensity: Float = 0.3
    public var blurRadius: Float = 0.5

    public var pipelineFilters: [C7FilterProtocol] {
        let vignetteEnd = 0.3 + (0.75 - 0.3) * (1.0 - vignetteIntensity)
        return [
            MPSGaussianBlur(radius: blurRadius),
            C7Contrast(contrast: contrast),
            C7Saturation(saturation: saturation),
            C7Exposure(exposure: exposure),
            C7Vignette(start: 0.3, end: vignetteEnd, color: .zero)
        ]
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7CombinationBlendIntensity"),
            factors: [intensity],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

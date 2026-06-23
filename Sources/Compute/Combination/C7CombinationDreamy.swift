//
//  C7CombinationDreamy.swift
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

import Foundation

public final class C7CombinationDreamy: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var blurStrength: Float = 0.3
    public var warmth: Float = 0.2
    public var softness: Float = 0.4

    public var pipelineFilters: [C7FilterProtocol] {
        [
            MPSGaussianBlur(radius: max(0.0, min(1.0, blurStrength)) * 5.0),
            C7Saturation(saturation: 1.1),
            C7Exposure(exposure: 0.1)
        ]
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7CombinationDreamy"),
            factors: [intensity, warmth, softness],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

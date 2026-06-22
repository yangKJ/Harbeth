//
//  C7CombinationColorGrading.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

public final class C7CombinationColorGrading: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var temperature: Float = 0.0
    public var tint: Float = 0.0
    public var contrast: Float = 1.2
    public var saturation: Float = 0.9
    public var highlights: Float = -0.2
    public var shadows: Float = 0.1
    public var midtones: Float = 0.0

    public var pipelineFilters: [C7FilterProtocol] {
        [
            C7Temperature(temperature: temperature, tint: tint),
            C7Contrast(contrast: contrast),
            C7Saturation(saturation: saturation),
            C7HighlightShadow(highlights: (highlights + 1.0) * 0.5, shadows: (shadows + 1.0) * 0.5)
        ]
    }

    public init(intensity: Float = 1.0) {
        self.intensity = intensity
    }

    public func applyAtTexture(form texture: MTLTexture, to destTexture: MTLTexture, for buffer: MTLCommandBuffer) throws -> MTLTexture {
        try FilterPipelineExecutor.apply(filter: self, source: texture, destination: destTexture, commandBuffer: buffer)
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7CombinationBlendIntensity"),
            factors: [intensity, midtones],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

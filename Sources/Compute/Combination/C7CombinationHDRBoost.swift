//
//  C7CombinationHDRBoost.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

public final class C7CombinationHDRBoost: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var hdrStrength: Float = 1.0
    public var contrast: Float = 1.5
    public var saturation: Float = 1.1
    public var sharpness: Float = 0.8
    public var highlights: Float = -0.4
    public var shadows: Float = 0.3

    public var pipelineFilters: [C7FilterProtocol] {
        [
            C7HighlightShadow(highlights: (highlights + 1.0) * 0.5, shadows: (shadows + 1.0) * 0.5),
            C7Contrast(contrast: contrast),
            C7Saturation(saturation: saturation),
            C7Sharpen(sharpness: sharpness)
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
            factors: [intensity, hdrStrength],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

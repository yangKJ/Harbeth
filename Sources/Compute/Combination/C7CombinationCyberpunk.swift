//
//  C7CombinationCyberpunk.swift
//  Harbeth
//
//  Created by Condy on 2026/3/14.
//

import Foundation

public final class C7CombinationCyberpunk: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var neonGlow: Float = 0.8
    public var contrast: Float = 1.8
    public var saturation: Float = 1.5
    public var colorShift: Float = 0.6

    public var pipelineFilters: [C7FilterProtocol] {
        [
            C7Contrast(contrast: contrast),
            C7Saturation(saturation: saturation),
            C7Sharpen(sharpness: 1.0)
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
            modifier: .compute(kernel: "C7CombinationCyberpunk"),
            factors: [intensity, neonGlow, colorShift],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

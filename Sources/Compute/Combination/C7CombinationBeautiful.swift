//
//  C7CombinationBeautiful.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation

public final class C7CombinationBeautiful: C7FilterPipelineProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public var smoothDegree: Float = 0.0
    public var sigmaSpace: Float = 10.0
    public var sigmaColor: Float = 0.1
    public var radius: Float = 5.0
    public var edgeStrength: Float = 1.0

    public var pipelineExecutionStyle: FilterPipelineExecutionStyle { .parallelFromSource }

    public var pipelineFilters: [C7FilterProtocol] {
        [
            C7BilateralBlur(sigmaSpace: sigmaSpace, sigmaColor: sigmaColor, radius: radius),
            C7Sobel(edgeStrength: edgeStrength)
        ]
    }

    public init(smoothDegree: Float = 0.0, intensity: Float = 1.0) {
        self.intensity = intensity
        self.smoothDegree = smoothDegree
    }

    public func applyAtTexture(form texture: MTLTexture, to destTexture: MTLTexture, for buffer: MTLCommandBuffer) throws -> MTLTexture {
        try FilterPipelineExecutor.apply(filter: self, source: texture, destination: destTexture, commandBuffer: buffer)
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7CombinationBeautiful"),
            factors: [intensity, smoothDegree],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

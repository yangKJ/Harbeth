//
//  C7Canny.swift
//  Harbeth
//
//  Created by Condy on 2026/2/7.
//

import Foundation

/// 统一灰度输入，执行完整的 Canny 滞后连接，输出灰度 RGB 与不透明 alpha。
public struct C7Canny: C7FilterPipelineProtocol {
    @ZeroOneRange public var threshold1: Float = 0.2
    @ZeroOneRange public var threshold2: Float = 0.4

    public var pipelineFilters: [C7FilterProtocol] {
        [C7Grayed(with: .luminosity), MPSCanny(lowThreshold: threshold1, highThreshold: threshold2)]
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(inputAlphaExpectation: .premultiplied, outputAlpha: .opaque,
            precision: .float16, samplingFootprint: .global, coordinateDependency: .fullImage, fusionPolicy: .disabled)
    }

    public var kernelOutputContract: RenderOutputContract { RenderOutputContract(alpha: .opaque) }

    public init(threshold1: Float = 0.2, threshold2: Float = 0.4) {
        self.threshold1 = max(0.01, min(0.99, threshold1))
        self.threshold2 = max(self.threshold1 + 0.01, min(1.0, threshold2))
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(modifier: .compute(kernel: "C7CannyFinal"), otherInputTextures: otherInputTextures ?? [])
    }
}

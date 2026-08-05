//
//  C7DocumentBinarization.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation

/// 适用于纸张、票据和扫描件的局部自适应黑白二值化。
///
/// 与全局 `C7LuminanceThreshold` 不同，该滤镜先估计局部背景亮度，因此能更好地
/// 处理纸张阴影和不均匀照明。它只负责单帧图像处理，不包含文档检测或透视校正。
public final class C7DocumentBinarization: C7FilterPipelineProtocol {

    /// 局部背景估计半径。
    @Clamping(1...100) public var radius: Float = 18

    /// 相对局部背景的阈值偏移。值越大，越多区域会被判定为白色背景。
    @Clamping(0...0.5) public var threshold: Float = 0.12

    /// 黑白边界的软化宽度。0 为严格二值输出。
    @Clamping(0...0.25) public var softness: Float = 0.01

    public var pipelineFilters: [C7FilterProtocol] {
        [MPSGaussianBlur(radius: radius)]
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .clampsToUnitRange,
            samplingFootprint: .neighborhood(
                radius: MPSGaussianBlur.conservativeHaloRadius(for: radius)
            )
        )
    }

    public init(radius: Float = 18, threshold: Float = 0.12, softness: Float = 0.01) {
        self.radius = radius
        self.threshold = threshold
        self.softness = softness
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7DocumentBinarization"),
            factors: [threshold, softness],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

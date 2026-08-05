//
//  C7HighlightShadowTone.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation
import Metal

/// 高光阴影色调调整滤镜，使用 YIQ 颜色空间进行调整
/// Highlight and shadow tone adjustment filter, use YIQ color space to adjust
public struct C7HighlightShadowTone: C7FilterPipelineProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    public static let radiusRange: ParameterRange<Float, Self> = .init(min: 0.0, max: 100.0, value: 30.0)
    
    /// 阴影调整，-1.0-1.0，0代表原图，值越大阴影越亮
    /// Shadows adjustment, -1.0-1.0, 0 represents original image, higher values lighten shadows
    @Clamping(range.min...range.max) public var shadows: Float = range.value
    
    /// 高光调整，-1.0-1.0，0代表原图，值越小高光越暗
    /// Highlights adjustment, -1.0-1.0, 0 represents original image, lower values darken highlights
    @Clamping(range.min...range.max) public var highlights: Float = range.value
    
    /// 中间调调整，-1.0-1.0，0代表原图，值越大中间调越亮
    /// Midtones adjustment, -1.0-1.0, 0 represents original image, higher values lighten midtones
    @Clamping(range.min...range.max) public var midtones: Float = range.value
    
    /// 对比度调整，-1.0-1.0，0代表原始对比度
    /// Contrast adjustment, -1.0-1.0, 0 represents original contrast
    @Clamping(range.min...range.max) public var contrast: Float = range.value

    /// 用于建立局部亮度参考的高斯模糊半径。0 表示直接使用原图作为参考。
    @Clamping(radiusRange.min...radiusRange.max) public var radius: Float = radiusRange.value
    
    public var pipelineFilters: [C7FilterProtocol] {
        if radius == 0 {
            return [C7GaussianBlur(radius: 0)]
        }
        return [MPSGaussianBlur(radius: radius)]
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .neighborhood(
                radius: MPSGaussianBlur.conservativeHaloRadius(for: radius)
            )
        )
    }
    
    public init(
        shadows: Float = 0,
        highlights: Float = 0,
        midtones: Float = 0,
        contrast: Float = 0,
        radius: Float = radiusRange.value
    ) {
        self.shadows = shadows
        self.highlights = highlights
        self.midtones = midtones
        self.contrast = contrast
        self.radius = radius
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        PipelineLeafFilter(
            modifier: .compute(kernel: "C7HighlightShadowTone"),
            factors: [shadows, highlights, midtones, contrast],
            otherInputTextures: otherInputTextures ?? []
        )
    }
}

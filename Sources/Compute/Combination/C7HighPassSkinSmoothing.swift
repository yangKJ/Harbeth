//
//  C7HighPassSkinSmoothing.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation

/// 高反差保留平滑。
///
/// 该滤镜通过颜色通道生成细节引导层，再以高斯模糊提取高频细节并保护纹理区域。
/// 它不会执行人脸检测或皮肤区域识别；需要局部皮肤处理时，应配合 Harbeth 的 mask primitive。
public final class C7HighPassSkinSmoothing: C7FilterPipelineProtocol {

    public static let amountRange: ParameterRange<Float, C7HighPassSkinSmoothing> = .init(min: 0, max: 1, value: 0.65)
    public static let radiusRange: ParameterRange<Float, C7HighPassSkinSmoothing> = .init(min: 0, max: 100, value: 8)
    public static let sharpnessFactorRange: ParameterRange<Float, C7HighPassSkinSmoothing> = .init(min: 0, max: 1, value: 0)
    public static let defaultDetailThreshold: Float = 75.0 / 255.0
    public static let defaultDetailTransition: Float = 89.0 / 255.0
    public static let defaultToneCurveInputMidpoint: Float = 120.0 / 255.0
    public static let defaultToneCurveOutputMidpoint: Float = 146.0 / 255.0

    /// 平滑强度。0 保持原图，1 应用完整效果。
    @Clamping(amountRange.min...amountRange.max) public var amount: Float = amountRange.value

    /// 高斯模糊半径，用于分离低频肤色和高频纹理。
    @Clamping(radiusRange.min...radiusRange.max) public var radius: Float = radiusRange.value

    /// 高频保护阈值。值越低，越多细节区域会保留原图。
    @ZeroOneRange public var detailThreshold: Float = defaultDetailThreshold

    /// 高频保护过渡宽度，避免阈值边缘产生突变。
    @Clamping(1.0 / 255.0...1.0) public var detailTransition: Float = defaultDetailTransition

    /// 最终细节锐化系数。0 保持默认平滑视觉，1 应用完整的四邻域高频增强。
    @Clamping(sharpnessFactorRange.min...sharpnessFactorRange.max) public var sharpnessFactor: Float = sharpnessFactorRange.value

    /// 色调曲线的输入中点。限制在开区间内，避免曲线求值除零。
    @Clamping(1.0 / 255.0...1.0 - 1.0 / 255.0) public var toneCurveInputMidpoint: Float = defaultToneCurveInputMidpoint

    /// 色调曲线在输入中点处的输出值。
    @ZeroOneRange public var toneCurveOutputMidpoint: Float = defaultToneCurveOutputMidpoint

    public var pipelineFilters: [C7FilterProtocol] {
        [
            HighPassSkinChannelOverlay(),
            radius == 0 ? C7GaussianBlur(radius: 0) : MPSGaussianBlur(radius: radius)
        ]
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .neighborhood(
                radius: max(MPSGaussianBlur.conservativeHaloRadius(for: radius), 1)
            )
        )
    }

    public init(
        amount: Float = amountRange.value,
        radius: Float = radiusRange.value,
        detailThreshold: Float = defaultDetailThreshold,
        detailTransition: Float = defaultDetailTransition,
        sharpnessFactor: Float = sharpnessFactorRange.value,
        toneCurveInputMidpoint: Float = defaultToneCurveInputMidpoint,
        toneCurveOutputMidpoint: Float = defaultToneCurveOutputMidpoint
    ) {
        self.amount = amount
        self.radius = radius
        self.detailThreshold = detailThreshold
        self.detailTransition = detailTransition
        self.sharpnessFactor = sharpnessFactor
        self.toneCurveInputMidpoint = toneCurveInputMidpoint
        self.toneCurveOutputMidpoint = toneCurveOutputMidpoint
    }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        guard let blurredDetailGuide = otherInputTextures?.first else {
            return PipelineLeafFilter(
                modifier: .compute(kernel: "C7HighPassSkinSmoothingComposite"),
                factors: [
                    amount,
                    detailThreshold,
                    detailTransition,
                    sharpnessFactor,
                    toneCurveInputMidpoint,
                    toneCurveOutputMidpoint
                ]
            )
        }
        return PipelineLeafFilter(
            modifier: .compute(kernel: "C7HighPassSkinSmoothingComposite"),
            factors: [
                amount,
                detailThreshold,
                detailTransition,
                sharpnessFactor,
                toneCurveInputMidpoint,
                toneCurveOutputMidpoint
            ],
            otherInputTextures: [blurredDetailGuide]
        )
    }
}

private struct HighPassSkinChannelOverlay: C7FilterProtocol {
    var modifier: ModifierEnum {
        .compute(kernel: "C7HighPassSkinChannelOverlay")
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
}

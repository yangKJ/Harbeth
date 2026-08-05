//
//  C7CMYKHalftone.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation

/// 使用标准 CMYK 网角生成四色印刷网点。
///
/// 与 `C7Halftone` 的单色亮度网点不同，该滤镜分别计算青、品红、黄、黑四个网屏，
/// 再以减色模型合成结果。
public struct C7CMYKHalftone: C7FilterProtocol {

    public static let widthRange: ParameterRange<Float, Self> = .init(min: 0.002, max: 0.2, value: 0.025)

    /// 网格单元相对完整画布短边的比例。
    @Clamping(widthRange.min...widthRange.max) public var fractionalWidth: Float = widthRange.value

    /// CMYK 网点结果与原图的混合强度。
    @ZeroOneRange public var intensity: Float = 1

    public var modifier: ModifierEnum {
        .compute(kernel: "C7CMYKHalftone")
    }

    public var factors: [Float] {
        [fractionalWidth, intensity]
    }

    public var memoryAccessPattern: MemoryAccessPattern { .neighborhood }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .clampsToUnitRange,
            samplingFootprint: .dynamic,
            coordinateDependency: .fullImage,
            globalDependency: .imageDimensions,
            fusionPolicy: .disabled
        )
    }

    /// 旋转网格中从输出像素到采样单元中心的保守画布比例上界。
    public var conservativeSampleDisplacementFraction: Float {
        Self.conservativeSampleDisplacementFraction(for: fractionalWidth)
    }

    public init(fractionalWidth: Float = widthRange.value, intensity: Float = 1) {
        self.fractionalWidth = fractionalWidth
        self.intensity = intensity
    }

    public static func conservativeSampleDisplacementFraction(for fractionalWidth: Float) -> Float {
        guard fractionalWidth.isFinite else { return widthRange.value * Float(2).squareRoot() }
        let width = min(max(fractionalWidth, widthRange.min), widthRange.max)
        return min(1, width * Float(2).squareRoot())
    }
}

//
//  C7ToneMapping.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation

/// 在线性 RGB 中执行确定性亮度 tone mapping。
///
/// 输入单位通过 `inputNitsPerUnit` 显式定义。例如 Harbeth 的 PQ decode
/// 使用 `1.0 == 10_000 nits`，HLG decode 默认使用 `1.0 == 1_000 nits`。
/// 输出 `1.0` 对应 `targetReferenceWhiteNits`；当目标峰值高于参考白时，
/// 结果会保留大于 1 的线性 EDR headroom。
public struct C7ToneMapping: C7FilterProtocol {

    public let inputNitsPerUnit: Float
    public let sourcePeakNits: Float
    public let targetReferenceWhiteNits: Float
    public let targetPeakNits: Float
    public let shoulderStrength: Float
    public let highlightDesaturation: Float

    public var modifier: ModifierEnum {
        .compute(kernel: "C7ToneMapping")
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "sourceLuminance",
                index: 0,
                stage: .compute,
                value: .float2(SIMD2<Float>(inputNitsPerUnit, sourcePeakNits))
            ),
            KernelParameterBinding(
                name: "targetLuminance",
                index: 1,
                stage: .compute,
                value: .float2(SIMD2<Float>(targetReferenceWhiteNits, targetPeakNits))
            ),
            KernelParameterBinding(
                name: "appearance",
                index: 2,
                stage: .compute,
                value: .float2(SIMD2<Float>(shoulderStrength, highlightDesaturation))
            )
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelPixelContract: KernelPixelContract {
        let linearRGB = ImageColorSpaceContract(
            name: "linearRGB",
            preservesInput: false,
            gamut: .preserveInput,
            transferFunction: .linear
        )
        let behavior: KernelDynamicRangeBehavior = targetPeakNits > targetReferenceWhiteNits ? .toneMapsToEDR : .toneMapsToSDR
        return KernelPixelContract(
            inputColorSpace: linearRGB,
            workingColorSpace: linearRGB,
            outputColorSpace: linearRGB,
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: behavior,
            samplingFootprint: .point,
            coordinateDependency: .local,
            globalDependency: .none,
            fusionPolicy: .pointwise
        )
    }

    public init(
        inputNitsPerUnit: Float,
        sourcePeakNits: Float,
        targetReferenceWhiteNits: Float,
        targetPeakNits: Float,
        shoulderStrength: Float = 4,
        highlightDesaturation: Float = 0.12
    ) {
        let referenceWhite = Self.positive(targetReferenceWhiteNits, fallback: 100)
        self.inputNitsPerUnit = Self.positive(inputNitsPerUnit, fallback: 1_000)
        self.sourcePeakNits = max(Self.positive(sourcePeakNits, fallback: 1_000), referenceWhite)
        self.targetReferenceWhiteNits = referenceWhite
        self.targetPeakNits = max(Self.positive(targetPeakNits, fallback: referenceWhite), referenceWhite)
        self.shoulderStrength = min(max(shoulderStrength.isFinite ? shoulderStrength : 4, 0.05), 16)
        self.highlightDesaturation = min(max(highlightDesaturation.isFinite ? highlightDesaturation : 0.12, 0), 1)
    }

    private static func positive(_ value: Float, fallback: Float) -> Float {
        guard value.isFinite, value > 0 else { return fallback }
        return value
    }
}

//
//  C7LevelsAdjustment.swift
//  Harbeth
//
//  Created by Condy on 2026/10/10.
//

import Foundation

/// 数值型RGB色阶；对直色值求值后恢复预乘，gamma不受颜色对象的单位范围限制。
public struct C7LevelsAdjustment: C7FilterProtocol {
    public var inputBlack: SIMD3<Float>
    public var gamma: SIMD3<Float>
    public var inputWhite: SIMD3<Float>
    public var outputBlack: SIMD3<Float>
    public var outputWhite: SIMD3<Float>

    public init(inputBlack: SIMD3<Float> = .zero, gamma: SIMD3<Float> = SIMD3(repeating: 1),
                inputWhite: SIMD3<Float> = SIMD3(repeating: 1), outputBlack: SIMD3<Float> = .zero,
                outputWhite: SIMD3<Float> = SIMD3(repeating: 1)) {
        self.inputBlack = inputBlack
        self.gamma = gamma
        self.inputWhite = inputWhite
        self.outputBlack = outputBlack
        self.outputWhite = outputWhite
    }

    public var modifier: ModifierEnum { .compute(kernel: "C7LevelsAdjustment") }
    public var memoryAccessPattern: MemoryAccessPattern { .point }
    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(precision: .float16, dynamicRangeBehavior: .clampsToUnitRange,
                            samplingFootprint: .point, fusionPolicy: .pointwise)
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        let black = bounded(inputBlack, lower: .zero, upper: SIMD3(repeating: 254.0 / 255), fallback: .zero)
        let white = bounded(inputWhite, lower: black + SIMD3(repeating: 1.0 / 255),
                            upper: SIMD3(repeating: 1), fallback: SIMD3(repeating: 1))
        let middle = bounded(gamma, lower: SIMD3(repeating: 0.1), upper: SIMD3(repeating: 9.99), fallback: SIMD3(repeating: 1))
        let lowOutput = bounded(outputBlack, lower: .zero, upper: SIMD3(repeating: 1), fallback: .zero)
        let highOutput = bounded(outputWhite, lower: .zero, upper: SIMD3(repeating: 1), fallback: SIMD3(repeating: 1))
        return [
            .init(name: "inputBlack", index: 0, stage: .compute, value: .float3(black)),
            .init(name: "gamma", index: 1, stage: .compute, value: .float3(middle)),
            .init(name: "inputWhite", index: 2, stage: .compute, value: .float3(white)),
            .init(name: "outputBlack", index: 3, stage: .compute, value: .float3(lowOutput)),
            .init(name: "outputWhite", index: 4, stage: .compute, value: .float3(highOutput))
        ]
    }

    private func bounded(_ values: SIMD3<Float>, lower: SIMD3<Float>, upper: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        var result = values
        for i in 0..<3 { result[i] = values[i].isFinite ? min(upper[i], max(lower[i], values[i])) : fallback[i] }
        return result
    }
}

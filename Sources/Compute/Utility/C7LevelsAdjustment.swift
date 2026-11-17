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
        KernelPixelContract(inputAlphaExpectation: .premultiplied, outputAlpha: .preserveInput, precision: .float32, dynamicRangeBehavior: .clampsToUnitRange,
                            samplingFootprint: .point, fusionPolicy: .pointwise)
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        LevelsParameters(inputBlack: inputBlack, gamma: gamma, inputWhite: inputWhite, outputBlack: outputBlack, outputWhite: outputWhite)
            .bindings(names: ["inputBlack", "gamma", "inputWhite", "outputBlack", "outputWhite"])
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }
}

// 两种色阶入口使用相同的参数域，保留输出范围反向映射。
struct LevelsParameters {
    let black: SIMD3<Float>, middle: SIMD3<Float>, white: SIMD3<Float>, low: SIMD3<Float>, high: SIMD3<Float>
    init(inputBlack: SIMD3<Float>, gamma: SIMD3<Float>, inputWhite: SIMD3<Float>, outputBlack: SIMD3<Float>, outputWhite: SIMD3<Float>) {
        black = Self.bounded(inputBlack, lower: .zero, upper: SIMD3(repeating: 254.0 / 255), fallback: .zero)
        white = Self.bounded(inputWhite, lower: black + SIMD3(repeating: 1.0 / 255), upper: SIMD3(repeating: 1), fallback: SIMD3(repeating: 1))
        middle = Self.bounded(gamma, lower: SIMD3(repeating: 0.1), upper: SIMD3(repeating: 9.99), fallback: SIMD3(repeating: 1))
        low = Self.bounded(outputBlack, lower: .zero, upper: SIMD3(repeating: 1), fallback: .zero)
        high = Self.bounded(outputWhite, lower: .zero, upper: SIMD3(repeating: 1), fallback: SIMD3(repeating: 1))
    }
    func bindings(names: [String]) -> [KernelParameterBinding] {
        zip(names, [black, middle, white, low, high]).enumerated().map {
            .init(name: $0.element.0, index: $0.offset, stage: .compute, value: .float3($0.element.1))
        }
    }
    private static func bounded(_ values: SIMD3<Float>, lower: SIMD3<Float>, upper: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        var result = values
        for i in 0..<3 { result[i] = values[i].isFinite ? min(upper[i], max(lower[i], values[i])) : fallback[i] }
        return result
    }
}

//
//  C7ColorGrading.swift
//  Harbeth
//
//  Created by Condy on 2026/7/23.
//

import Foundation

/// 分别作用于阴影、中间调、高光与全局的色彩分级滤镜。
/// 每个 SIMD3 依次表达色相角度、饱和度和明度。
public struct C7ColorGrading: C7FilterProtocol {

    public var shadows: SIMD3<Float>
    public var midtones: SIMD3<Float>
    public var highlights: SIMD3<Float>
    public var global: SIMD3<Float>
    @Clamping(-1...1) public var balance: Float = 0
    @ZeroOneRange public var blending: Float = 0.5

    public var modifier: ModifierEnum {
        .compute(kernel: "C7ColorGrading")
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "shadows", index: 0, stage: .compute, value: .float3(normalized(shadows))),
            KernelParameterBinding(name: "midtones", index: 1, stage: .compute, value: .float3(normalized(midtones))),
            KernelParameterBinding(name: "highlights", index: 2, stage: .compute, value: .float3(normalized(highlights))),
            KernelParameterBinding(name: "global", index: 3, stage: .compute, value: .float3(normalized(global))),
            KernelParameterBinding(name: "balance", index: 4, stage: .compute, value: .float(balance)),
            KernelParameterBinding(name: "blending", index: 5, stage: .compute, value: .float(blending))
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init(
        shadows: SIMD3<Float> = .zero,
        midtones: SIMD3<Float> = .zero,
        highlights: SIMD3<Float> = .zero,
        global: SIMD3<Float> = .zero,
        balance: Float = 0,
        blending: Float = 0.5
    ) {
        self.shadows = shadows
        self.midtones = midtones
        self.highlights = highlights
        self.global = global
        self.balance = balance
        self.blending = blending
    }

    private func normalized(_ value: SIMD3<Float>) -> SIMD3<Float> {
        let hue = value.x.isFinite ? value.x.truncatingRemainder(dividingBy: 360) : 0
        return SIMD3<Float>(
            hue,
            min(1, max(0, value.y)),
            min(1, max(-1, value.z))
        )
    }
}

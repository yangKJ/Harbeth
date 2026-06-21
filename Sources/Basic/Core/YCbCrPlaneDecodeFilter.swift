//
//  YCbCrPlaneDecodeFilter.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import simd

struct YCbCrPlaneDecodeFilter: C7FilterProtocol {
    enum Layout: String {
        case biPlanar
        case triPlanar

        var kernelName: String {
            switch self {
            case .biPlanar:
                return "C7YCbCrBiPlanarToRGBA"
            case .triPlanar:
                return "C7YCbCrTriPlanarToRGBA"
            }
        }
    }

    let layout: Layout
    let conversionMatrix: Matrix3x3
    let conversionOffset: SIMD3<Float>
    let planeTextures: [MTLTexture]

    var modifier: ModifierEnum {
        .compute(kernel: layout.kernelName)
    }

    var otherInputTextures: C7InputTextures {
        Array(planeTextures.dropFirst())
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "conversionMatrix",
                index: 0,
                stage: .compute,
                value: .matrix3x3(conversionMatrix)
            ),
            KernelParameterBinding(
                name: "conversionOffset",
                index: 1,
                stage: .compute,
                value: .float3(conversionOffset)
            )
        ]
    }

    func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        // 旧入口先保留，新的执行链优先走 kernelParameterBindings。
    }
}

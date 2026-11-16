//
//  YCbCrPlaneDecodeFilter.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
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
                return "InnerYCbCrBiPlanarToRGBA"
            case .triPlanar:
                return "InnerYCbCrTriPlanarToRGBA"
            }
        }
    }

    let layout: Layout
    let conversionMatrix: Matrix3x3
    let conversionOffset: SIMD3<Float>
    let planeTextures: [MTLTexture]
    var geometry: C7TextureGeometry? = nil

    func resize(input size: C7Size) -> C7Size { geometry?.resize(input: size) ?? size }

    var modifier: ModifierEnum {
        .compute(kernel: layout.kernelName + (geometry == nil ? "" : "Geometry"))
    }

    var otherInputTextures: C7InputTextures {
        Array(planeTextures.dropFirst())
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .multiTexture
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        var bindings = [
            KernelParameterBinding(name: "conversionMatrix", index: 0, stage: .compute, value: .matrix3x3(conversionMatrix)),
            KernelParameterBinding(name: "conversionOffset", index: 1, stage: .compute, value: .float3(conversionOffset))
        ]
        if let geometry {
            bindings += geometry.kernelParameterBindings.map {
                KernelParameterBinding(name: $0.name, index: $0.index + 2, stage: .compute, value: $0.value)
            }
        }
        return bindings
    }
}

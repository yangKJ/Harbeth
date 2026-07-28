//
//  C7UnpremultiplyAlpha.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 将 premultiplied RGBA 转为 non-premultiplied。
public struct C7UnpremultiplyAlpha: C7FilterProtocol {

    public var modifier: ModifierEnum {
        .compute(kernel: "C7UnpremultiplyAlpha")
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .nonPremultiplied,
            precision: .float16,
            dynamicRangeBehavior: .clampsToUnitRange,
            samplingFootprint: .point,
            fusionPolicy: .pointwise
        )
    }

    public init() {}
}

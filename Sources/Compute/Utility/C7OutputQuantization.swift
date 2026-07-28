//
//  C7OutputQuantization.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation

/// 最终整数输出前的确定性颜色量化与抖动。
public struct C7OutputQuantization: C7FilterProtocol {
    public let bitDepth: Int
    public let pattern: ImageDitherPattern
    public let strength: Float
    public let seed: UInt32

    public var modifier: ModifierEnum {
        .compute(kernel: "C7OutputQuantization")
    }

    public var factors: [Float] {
        [
            Float(bitDepth),
            pattern.factorValue,
            min(max(strength, 0), 1),
            Float(seed)
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern { .point }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            precision: .float16,
            dynamicRangeBehavior: .clampsToUnitRange,
            samplingFootprint: .point,
            coordinateDependency: .absoluteInput,
            fusionPolicy: .pointwise
        )
    }

    public init(bitDepth: Int = 8, pattern: ImageDitherPattern = .ordered4x4, strength: Float = 1, seed: UInt32 = 0) {
        self.bitDepth = min(max(bitDepth, 1), 16)
        self.pattern = pattern
        self.strength = min(max(strength, 0), 1)
        self.seed = seed
    }

    public init(contract: OutputQuantizationContract) {
        self.init(
            bitDepth: contract.bitDepth,
            pattern: contract.ditherPattern,
            strength: contract.strength,
            seed: contract.seed
        )
    }
}

private extension ImageDitherPattern {
    var factorValue: Float {
        switch self {
        case .none: return 0
        case .ordered4x4: return 1
        case .interleavedGradient: return 2
        }
    }
}

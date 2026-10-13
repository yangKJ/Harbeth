//
//  C7OrderedDither.swift
//  Harbeth
//
//  Created by Condy on 2026/10/14.
//

import Foundation

/// 按文档像素单元平均颜色并量化，保持每个源像素的 Alpha。
public struct C7OrderedDither: C7FilterProtocol {
    public let levels: Int
    public let pixelSize: Int
    public let pattern: ImageDitherPattern
    public let strength: Float
    public let seed: UInt32

    public var modifier: ModifierEnum { .compute(kernel: "C7OrderedDither") }

    public var factors: [Float] {
        [Float(levels), Float(pixelSize), pattern.factorValue, strength, Float(seed)]
    }

    public var memoryAccessPattern: MemoryAccessPattern { .neighborhood }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .clampsToUnitRange,
            samplingFootprint: pixelSize == 1 ? .point : .neighborhood(radius: pixelSize - 1),
            coordinateDependency: .absoluteInput,
            globalDependency: .imageDimensions,
            fusionPolicy: .disabled
        )
    }

    public init(
        levels: Int = 8,
        pixelSize: Int = 1,
        pattern: ImageDitherPattern = .ordered4x4,
        strength: Float = 1,
        seed: UInt32 = 0
    ) {
        self.levels = min(max(levels, 2), 256)
        self.pixelSize = min(max(pixelSize, 1), 32)
        self.pattern = pattern
        self.strength = strength.isFinite ? min(max(strength, 0), 1) : 1
        self.seed = seed
    }
}

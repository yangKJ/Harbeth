//
//  C7WhitesBlacks.swift
//  Harbeth
//
//  Created by Condy on 2026/7/23.
//

import Foundation

/// 独立调整白色色阶与黑色色阶的点采样滤镜。
public struct C7WhitesBlacks: C7FilterProtocol {

    public static let range: ClosedRange<Float> = -1...1

    @Clamping(range) public var whites: Float = 0
    @Clamping(range) public var blacks: Float = 0

    public var modifier: ModifierEnum {
        .compute(kernel: "C7WhitesBlacks")
    }

    public var factors: [Float] {
        [whites.isFinite ? whites : 0, blacks.isFinite ? blacks : 0]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, precision: .float32,
              dynamicRangeBehavior: .preservesExtendedRange, samplingFootprint: .point)
    }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }

    public init(whites: Float = 0, blacks: Float = 0) {
        self.whites = whites
        self.blacks = blacks
    }
}

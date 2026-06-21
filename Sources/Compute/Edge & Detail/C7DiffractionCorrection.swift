//
//  C7DiffractionCorrection.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 用于补偿小光圈衍射带来的细节损失。
///
/// 本质上是受阈值保护的 capture sharpening，
/// 目标是恢复被 diffraction softening 吃掉的高频细节，
/// 而不是替代创意锐化。
public struct C7DiffractionCorrection: C7FilterProtocol {

    public static let amountRange: ParameterRange<Float, Self> = .init(min: 0.0, max: 2.0, value: 0.0)
    public static let radiusRange: ParameterRange<Float, Self> = .init(min: 1.0, max: 2.0, value: 1.0)

    @Clamping(amountRange.min...amountRange.max) public var amount: Float = amountRange.value
    @Clamping(radiusRange.min...radiusRange.max) public var radius: Float = radiusRange.value
    @ZeroOneRange public var edgeThreshold: Float = 0.08

    public var modifier: ModifierEnum {
        .compute(kernel: "C7DiffractionCorrection")
    }

    public var factors: [Float] {
        [amount, radius, edgeThreshold]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public init(amount: Float = amountRange.value,
                radius: Float = radiusRange.value,
                edgeThreshold: Float = 0.08) {
        self.amount = amount
        self.radius = radius
        self.edgeThreshold = edgeThreshold
    }
}

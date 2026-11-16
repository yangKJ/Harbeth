//
//  C7Deband.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation

public struct C7Deband: C7FilterProtocol {

    public static let radiusRange: ClosedRange<Float> = 1...4
    public static let thresholdRange: ClosedRange<Float> = 0...0.5
    public static let amountRange: ClosedRange<Float> = 0...1
    public static let ditherRange: ClosedRange<Float> = 0...1

    @Clamping(radiusRange) public var radius: Float = 2
    @Clamping(thresholdRange) public var threshold: Float = 0.12
    @Clamping(amountRange) public var amount: Float = 0.7
    @Clamping(ditherRange) public var dither: Float = 0.15

    public var modifier: ModifierEnum {
        .compute(kernel: "C7Deband")
    }

    public var factors: [Float] {
        [safeRadius, threshold.isFinite ? threshold : 0, amount.isFinite ? amount : 0, dither.isFinite ? dither : 0]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float32,
            dynamicRangeBehavior: .clampsToUnitRange,
            samplingFootprint: .neighborhood(radius: Int(ceil(safeRadius)))
        )
    }

    private var safeRadius: Float { radius.isFinite ? radius : Self.radiusRange.lowerBound }

    public init(radius: Float = 2, threshold: Float = 0.12, amount: Float = 0.7, dither: Float = 0.15) {
        self.radius = radius
        self.threshold = threshold
        self.amount = amount
        self.dither = dither
    }
}

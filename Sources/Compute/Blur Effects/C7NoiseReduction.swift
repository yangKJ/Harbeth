//
//  C7NoiseReduction.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

public struct C7NoiseReduction: C7FilterProtocol {

    public static let radiusRange: ClosedRange<Float> = 1...8
    public static let amountRange: ClosedRange<Float> = 0...1
    public static let edgePreservationRange: ClosedRange<Float> = 0...1

    @Clamping(radiusRange) public var radius: Float = 3
    @Clamping(amountRange) public var amount: Float = 0.5
    @Clamping(edgePreservationRange) public var edgePreservation: Float = 0.8

    /// 预览相对原生像素的采样间距；默认 1 保持既有照片输出。
    @Clamping(0.001...1) public var sampleSpacing: Float = 1

    public var modifier: ModifierEnum {
        .compute(kernel: "C7NoiseReduction")
    }

    public var factors: [Float] {
        [radius, amount, edgePreservation, sampleSpacing]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, outputAlpha: .premultiplied,
              precision: .float32, samplingFootprint: .dynamic)
    }

    public init(radius: Float = 3, amount: Float = 0.5, edgePreservation: Float = 0.8, sampleSpacing: Float = 1) {
        self.radius = radius
        self.amount = amount
        self.edgePreservation = edgePreservation
        self.sampleSpacing = sampleSpacing
    }
}

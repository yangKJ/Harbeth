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

    public var modifier: ModifierEnum {
        .compute(kernel: "C7NoiseReduction")
    }

    public var factors: [Float] {
        [radius, amount, edgePreservation]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public init(radius: Float = 3, amount: Float = 0.5, edgePreservation: Float = 0.8) {
        self.radius = radius
        self.amount = amount
        self.edgePreservation = edgePreservation
    }
}

//
//  C7UnsharpMask.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

public struct C7UnsharpMask: C7FilterProtocol {

    public static let radiusRange: ClosedRange<Float> = 0...10
    public static let intensityRange: ClosedRange<Float> = 0...4
    public static let thresholdRange: ClosedRange<Float> = 0...1

    @Clamping(radiusRange) public var radius: Float = 2
    @Clamping(intensityRange) public var intensity: Float = 1
    @Clamping(thresholdRange) public var threshold: Float = 0

    public var modifier: ModifierEnum {
        .compute(kernel: "C7UnsharpMask")
    }

    public var factors: [Float] {
        [radius, intensity, threshold]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public init(radius: Float = 2, intensity: Float = 1, threshold: Float = 0) {
        self.radius = radius
        self.intensity = intensity
        self.threshold = threshold
    }
}

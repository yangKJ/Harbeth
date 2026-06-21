//
//  C7LensVignetteCorrection.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 镜头暗角补偿。
///
/// 与创意型 vignette 不同，这个滤镜的目标是补偿镜头带来的边缘失光，
/// 默认通过曝光式增亮来恢复角落亮度。
public struct C7LensVignetteCorrection: C7FilterProtocol {

    public var center: C7Point2D = .center

    /// Compensation amount in stops-like units.
    public var amount: Float

    /// Distance where compensation begins, normalized to the image radius.
    public var start: Float

    /// Distance where full compensation is reached, normalized to the image radius.
    public var end: Float

    public var modifier: ModifierEnum {
        .compute(kernel: "C7LensVignetteCorrection")
    }

    public var factors: [Float] {
        [center.x, center.y, amount, start, end]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init(center: C7Point2D = .center,
                amount: Float = 0,
                start: Float = 0.35,
                end: Float = 1.0) {
        self.center = center
        self.amount = amount
        self.start = start
        self.end = end
    }
}

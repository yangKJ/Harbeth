//
//  C7SharpnessFalloffCorrection.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 针对镜头边缘与角落锐度下滑的补偿。
///
/// 目标不是做全局锐化，而是只在外缘区域逐步增加 capture sharpening。
/// 这样更接近通用镜头补偿链路中的边缘锐度衰减校正语义。
public struct C7SharpnessFalloffCorrection: C7FilterProtocol {

    public var center: C7Point2D = .center

    /// 最大补偿强度。
    @ZeroOneRange public var amount: Float

    /// 开始进入补偿的半径位置。
    @ZeroOneRange public var start: Float

    /// 达到最大补偿的半径位置。
    @ZeroOneRange public var end: Float

    /// 边缘检测阈值，防止把平坦噪声区域也放大。
    @ZeroOneRange public var edgeThreshold: Float

    public var modifier: ModifierEnum {
        .compute(kernel: "C7SharpnessFalloffCorrection")
    }

    public var factors: [Float] {
        [center.x, center.y, amount, start, end, edgeThreshold]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public init(center: C7Point2D = .center,
                amount: Float = 0,
                start: Float = 0.45,
                end: Float = 1.0,
                edgeThreshold: Float = 0.2) {
        self.center = center
        self.amount = amount
        self.start = start
        self.end = end
        self.edgeThreshold = edgeThreshold
    }
}

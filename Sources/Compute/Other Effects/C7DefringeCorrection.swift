//
//  C7DefringeCorrection.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation

/// 用于压制高反差边缘的紫边与绿边。
///
/// 这类 fringe 更接近图像级补偿，不直接绑定镜头 profile。
/// 默认参数参考主流 RAW 编辑器的 optics / color defringe 语义：
/// - 紫边与绿边分别控制
/// - 用 hue range 保护正常主体颜色
/// - 只在高反差边缘显著生效
public struct C7DefringeCorrection: C7FilterProtocol {

    public var purpleAmount: Float
    public var purpleHueStart: Float
    public var purpleHueEnd: Float

    public var greenAmount: Float
    public var greenHueStart: Float
    public var greenHueEnd: Float

    public var edgeThreshold: Float
    public var saturationThreshold: Float

    public var modifier: ModifierEnum {
        .compute(kernel: "C7DefringeCorrection")
    }

    public var factors: [Float] {
        [
            purpleAmount,
            purpleHueStart,
            purpleHueEnd,
            greenAmount,
            greenHueStart,
            greenHueEnd,
            edgeThreshold,
            saturationThreshold
        ]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    public init(purpleAmount: Float = 0,
                purpleHueStart: Float = 250,
                purpleHueEnd: Float = 320,
                greenAmount: Float = 0,
                greenHueStart: Float = 90,
                greenHueEnd: Float = 170,
                edgeThreshold: Float = 0.08,
                saturationThreshold: Float = 0.15) {
        self.purpleAmount = purpleAmount
        self.purpleHueStart = purpleHueStart
        self.purpleHueEnd = purpleHueEnd
        self.greenAmount = greenAmount
        self.greenHueStart = greenHueStart
        self.greenHueEnd = greenHueEnd
        self.edgeThreshold = edgeThreshold
        self.saturationThreshold = saturationThreshold
    }
}

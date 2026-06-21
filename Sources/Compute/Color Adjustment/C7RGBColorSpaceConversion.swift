//
//  C7RGBColorSpaceConversion.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation

/// 针对显式 RGB color-space contract 的轻量转换。
///
/// 这个 primitive 只处理线性 RGB 空间中的 gamut matrix。
/// transfer decode/encode 继续交给 `C7RGBTransferConversion`，避免把完整
/// color-management runtime 提前塞进 Harbeth 的默认链路。
public struct C7RGBColorSpaceConversion: C7FilterProtocol {

    public enum Mode: Float, Sendable, Codable, Equatable, Hashable {
        case linearSRGBToLinearDisplayP3 = 0
        case linearDisplayP3ToLinearSRGB = 1
    }

    public let mode: Mode

    public var modifier: ModifierEnum {
        .compute(kernel: "C7RGBColorSpaceConversion")
    }

    public var factors: [Float] {
        [mode.rawValue]
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    public init(mode: Mode) {
        self.mode = mode
    }
}

//
//  C7RGBColorSpaceConversion.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation

/// 针对显式 RGB color-space contract 的轻量转换。
///
/// 这个 primitive 只覆盖 Harbeth 现阶段最常见、最稳定的几组底座合同：
/// - sRGB <-> DisplayP3
/// - DisplayP3 <-> extendedLinearSRGB
///
/// 这样 Harbeth 可以继续保持轻量，不把完整 ICC/runtime color management
/// 过早塞进默认执行链。
public struct C7RGBColorSpaceConversion: C7FilterProtocol {

    public enum Mode: Float, Sendable, Codable, Equatable, Hashable {
        case sRGBToDisplayP3 = 0
        case displayP3ToSRGB = 1
        case displayP3ToExtendedLinearSRGB = 2
        case extendedLinearSRGBToDisplayP3 = 3
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

    public init?(from source: ImageColorSpaceContract, to target: ImageColorSpaceContract) {
        guard let mode = target.colorConversionMode(from: source) else {
            return nil
        }
        self.init(mode: mode)
    }
}

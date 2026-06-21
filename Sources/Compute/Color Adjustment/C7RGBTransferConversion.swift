//
//  C7RGBTransferConversion.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation

/// 针对显式色彩 contract 的 RGB transfer-function 转换。
///
/// 这个滤镜只处理 transfer 曲线，不隐式处理 gamut 转换。
/// 这样可以避免在 source contract 不明确时偷偷加入产品色彩策略。
public struct C7RGBTransferConversion: C7FilterProtocol {

    public enum Mode: Float, Sendable, Codable, Equatable, Hashable {
        case sRGBToLinear = 0
        case linearToSRGB = 1
    }

    public let mode: Mode

    public var modifier: ModifierEnum {
        .compute(kernel: "C7RGBTransferConversion")
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
        guard let mode = target.transferConversionMode(from: source) else {
            return nil
        }
        self.init(mode: mode)
    }
}

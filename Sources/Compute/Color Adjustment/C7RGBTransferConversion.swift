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
        case pqToLinear = 2
        case linearToPQ = 3
        case hlgToLinear = 4
        case linearToHLG = 5
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

    public var kernelPixelContract: KernelPixelContract {
        let behavior: KernelDynamicRangeBehavior
        switch mode {
        case .sRGBToLinear, .linearToSRGB:
            behavior = .preservesExtendedRange
        case .pqToLinear, .linearToPQ, .hlgToLinear, .linearToHLG:
            behavior = .unspecified
        }
        return KernelPixelContract(
            precision: .float16,
            dynamicRangeBehavior: behavior,
            samplingFootprint: .point,
            fusionPolicy: .pointwise
        )
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

extension C7RGBTransferConversion.Mode {
    var isDecodeTransfer: Bool {
        switch self {
        case .sRGBToLinear, .pqToLinear, .hlgToLinear:
            return true
        case .linearToSRGB, .linearToPQ, .linearToHLG:
            return false
        }
    }
}

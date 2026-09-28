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
    private let inputColorSpace: ImageColorSpaceContract
    private let outputColorSpace: ImageColorSpaceContract

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
        return KernelPixelContract(
            inputColorSpace: inputColorSpace,
            workingColorSpace: inputColorSpace,
            outputColorSpace: outputColorSpace,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .point,
            fusionPolicy: .pointwise
        )
    }

    public init(mode: Mode) {
        self.mode = mode
        (inputColorSpace, outputColorSpace) = Self.defaultColorSpaces(for: mode)
    }

    public init?(from source: ImageColorSpaceContract, to target: ImageColorSpaceContract) {
        guard let mode = target.transferConversionMode(from: source) else {
            return nil
        }
        self.mode = mode
        self.inputColorSpace = source
        self.outputColorSpace = target
    }

    private static func defaultColorSpaces(
        for mode: Mode
    ) -> (ImageColorSpaceContract, ImageColorSpaceContract) {
        let linear2020 = ImageColorSpaceContract(
            name: "linearITU2020", preservesInput: false, gamut: .ituR2020, transferFunction: .linear
        )
        switch mode {
        case .sRGBToLinear: return (.sRGB, .extendedLinearSRGB)
        case .linearToSRGB: return (.extendedLinearSRGB, .sRGB)
        case .pqToLinear: return (.hdrPQ, linear2020)
        case .linearToPQ: return (linear2020, .hdrPQ)
        case .hlgToLinear: return (.hdrHLG, linear2020)
        case .linearToHLG: return (linear2020, .hdrHLG)
        }
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

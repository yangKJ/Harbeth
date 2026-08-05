//
//  C7Palettize.swift
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

import Foundation

/// 将每个像素映射到用户提供调色板中的最近颜色。
///
/// 该 primitive 不携带命名预设或品牌调色板；风格资产应由上层 package 管理。
public struct C7Palettize: C7FilterProtocol {

    public struct PaletteColor: Sendable, Codable, Equatable, Hashable {
        public let red: Float
        public let green: Float
        public let blue: Float

        public init(red: Float, green: Float, blue: Float) {
            self.red = Self.sanitized(red)
            self.green = Self.sanitized(green)
            self.blue = Self.sanitized(blue)
        }

        public init(_ color: C7Color) {
            let rgba = color.c7.toRGBA()
            self.init(red: rgba.red, green: rgba.green, blue: rgba.blue)
        }

        public static let black = PaletteColor(red: 0, green: 0, blue: 0)
        public static let white = PaletteColor(red: 1, green: 1, blue: 1)

        private static func sanitized(_ value: Float) -> Float {
            guard value.isFinite else { return 0 }
            return min(max(value, 0), 1)
        }
    }

    public static let maximumColorCount = 32
    public static let defaultPalette: [PaletteColor] = [.black, .white]

    /// 实际参与量化的调色板，最多保留 32 色。
    public private(set) var palette: [PaletteColor]

    /// 量化结果与原图的混合强度。
    @ZeroOneRange public var intensity: Float = 1

    public var modifier: ModifierEnum {
        .compute(kernel: "C7Palettize")
    }

    public var memoryAccessPattern: MemoryAccessPattern { .point }

    public var kernelParameterBindings: [KernelParameterBinding] {
        let flattened = palette.flatMap { [$0.red, $0.green, $0.blue, Float(1)] }
        return [
            KernelParameterBinding(name: "palette", index: 0, stage: .compute, value: .floatArray(flattened)),
            KernelParameterBinding(name: "paletteCount", index: 1, stage: .compute, value: .int(palette.count)),
            KernelParameterBinding(name: "intensity", index: 2, stage: .compute, value: .float(intensity))
        ]
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            inputAlphaExpectation: .premultiplied,
            outputAlpha: .premultiplied,
            precision: .float16,
            dynamicRangeBehavior: .clampsToUnitRange,
            samplingFootprint: .point,
            coordinateDependency: .local,
            fusionPolicy: .disabled
        )
    }

    public init(palette: [PaletteColor] = defaultPalette, intensity: Float = 1) {
        let normalizedPalette = palette.isEmpty ? Self.defaultPalette : palette
        self.palette = Array(normalizedPalette.prefix(Self.maximumColorCount))
        self.intensity = intensity
    }
}

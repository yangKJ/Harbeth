//
//  C7HSL.swift
//  Harbeth
//
//  Created by Condy on 2026/3/10.
//

import Foundation

/// HSL调整滤镜
/// HSL (Hue, Saturation, Lightness) adjustment filter
public struct C7HSL: C7FilterProtocol {
    
    /// 色相调整范围，-180.0 到 180.0，默认 0.0
    public static let hueRange: ParameterRange<Float, Self> = .init(min: -180.0, max: 180.0, value: 0.0)
    
    /// 饱和度调整范围，-1.0 到 1.0，默认 0.0
    public static let saturationRange: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    /// 明度调整范围，-1.0 到 1.0，默认 0.0
    public static let lightnessRange: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    @Clamping(hueRange.min...hueRange.max) public var hue: Float = hueRange.value
    @Clamping(saturationRange.min...saturationRange.max) public var saturation: Float = saturationRange.value
    @Clamping(lightnessRange.min...lightnessRange.max) public var lightness: Float = lightnessRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7HSL")
    }
    
    public var factors: [Float] {
        return [hue.isFinite ? hue : 0, saturation.isFinite ? saturation : 0, lightness.isFinite ? lightness : 0]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public var kernelPixelContract: KernelPixelContract {
        .init(
            inputAlphaExpectation: .premultiplied, precision: .float32,
            dynamicRangeBehavior: factors.allSatisfy { $0 == 0 } ? .preservesExtendedRange : .clampsToUnitRange,
            samplingFootprint: .point
        )
    }

    public var kernelOutputContract: RenderOutputContract { .premultipliedColorInput }

    public init(hue: Float = 0, saturation: Float = 0, lightness: Float = 0) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }
}

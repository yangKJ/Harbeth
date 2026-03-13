//
//  C7Temperature.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 色温调整滤镜，使用 YIQ 色彩空间，色彩调整更符合人眼感知
/// Temperature adjustment filter
public struct C7Temperature: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    /// Temperature adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    /// -1.0 is cooler (bluer), 1.0 is warmer (yellower)
    @Clamping(range.min...range.max) public var temperature: Float = range.value
    
    /// Tint adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    /// -1.0 is greener, 1.0 is pinker
    @Clamping(range.min...range.max) public var tint: Float = range.value
    
    /// Color shift adjustment, ranging from -1.0 to 1.0, with 0.0 being the original
    /// -1.0 is more cyan, 1.0 is more magenta
    @Clamping(range.min...range.max) public var colorShift: Float = range.value
    
    /// Intensity of the effect, ranging from 0.0 to 1.0, with 1.0 being full effect
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Temperature")
    }
    
    public var factors: [Float] {
        return [temperature, tint, colorShift, intensity]
    }
    
    public init(temperature: Float = range.value, tint: Float = range.value) {
        self.init(temperature: temperature, tint: tint, colorShift: 0.0, intensity: 1.0)
    }
    
    public init(temperature: Float = range.value, tint: Float = range.value, colorShift: Float = range.value) {
        self.init(temperature: temperature, tint: tint, colorShift: colorShift, intensity: 1.0)
    }
    
    public init(temperature: Float = range.value, tint: Float = range.value, colorShift: Float = range.value, intensity: Float = 1.0) {
        self.temperature = temperature
        self.tint = tint
        self.colorShift = colorShift
        self.intensity = intensity
    }
}

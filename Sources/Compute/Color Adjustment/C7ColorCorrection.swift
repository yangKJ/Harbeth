//
//  C7ColorCorrection.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 综合色彩校正滤镜，包含色阶、曲线、色彩平衡三个参数调节
/// Comprehensive color correction filter with levels, curves, and color balance controls
public struct C7ColorCorrection: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    /// 色阶调整，-1.0-1.0，0代表原图，值越大调整强度越强
    /// Levels adjustment, -1.0-1.0, 0 represents original image, higher values increase adjustment strength
    @Clamping(range.min...range.max) public var levels: Float = range.value
    
    /// 曲线调整，-1.0-1.0，0代表原图，值越大调整强度越强
    /// Curves adjustment, -1.0-1.0, 0 represents original image, higher values increase adjustment strength
    @Clamping(range.min...range.max) public var curves: Float = range.value
    
    /// 色彩平衡调整，-1.0-1.0，0代表原图，值越大调整强度越强
    /// Color balance adjustment, -1.0-1.0, 0 represents original image, higher values increase adjustment strength
    @Clamping(range.min...range.max) public var colorBalance: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorCorrection")
    }
    
    public var factors: [Float] {
        return [levels, curves, colorBalance]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public init(levels: Float = 0.0, curves: Float = 0.0, colorBalance: Float = 0.0) {
        self.levels = levels
        self.curves = curves
        self.colorBalance = colorBalance
    }
}

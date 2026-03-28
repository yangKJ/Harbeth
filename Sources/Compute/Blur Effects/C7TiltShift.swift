//
//  C7TiltShift.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 移轴滤镜
/// Tilt Shift filter
public struct C7TiltShift: C7FilterProtocol {
    
    public enum TiltShiftMode {
        case linear
        case radial
    }
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.2)
    
    /// 模糊半径，0.0 到 1.0，默认 0.2
    @Clamping(range.min...range.max) public var blurRadius: Float = range.value
    
    /// 清晰区域中心，0.0 到 1.0，默认 0.5
    @ZeroOneRange public var center: Float = 0.5
    
    /// 清晰区域大小，0.0 到 1.0，默认 0.3
    @ZeroOneRange public var size: Float = 0.3
    
    /// 过渡区域大小，0.0 到 1.0，默认 0.1
    @ZeroOneRange public var transition: Float = 0.1
    
    /// 移轴模式，线性或径向
    public var mode: TiltShiftMode = .linear
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7TiltShift")
    }
    
    public var factors: [Float] {
        return [blurRadius, center, size, transition, mode == .linear ? 1.0 : 0.0]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public init(blurRadius: Float = range.value, center: Float = 0.5, size: Float = 0.3, transition: Float = 0.1, mode: TiltShiftMode = .linear) {
        self.blurRadius = blurRadius
        self.center = center
        self.size = size
        self.transition = transition
        self.mode = mode
    }
}

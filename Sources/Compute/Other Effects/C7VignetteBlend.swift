//
//  C7VignetteBlend.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation

/// 暗角混合效果
/// 支持多种混合模式的暗角效果，使边缘的图像以不同方式淡化
public struct C7VignetteBlend: C7FilterProtocol {
    public enum BlendMode: Int {
        case normal = 0 // 正常混合
        case multiply   // 正片叠底
        case overlay    // 叠加
        case softLight  // 柔和光
    }
    
    /// The normalized distance from the center where the vignette effect starts, with a default of 0.3
    public var start: Float = 0.3
    /// The normalized distance from the center where the vignette effect ends, with a default of 0.75
    public var end: Float = 0.75
    public var center: C7Point2D = C7Point2D.center
    /// Keep the color scheme
    public var color: C7Color = .zero
    /// Blend mode for vignette effect
    public var blendMode: BlendMode = .normal
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7VignetteBlend")
    }
    
    public var factors: [Float] {
        return [center.x, center.y, start, end, Float(blendMode.rawValue)]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = Vector3.init(color: color).to_factor()
        computeEncoder.setBytes(&factor, length: Vector3.size, index: index + 1)
    }
    
    public init(start: Float = 0.3, end: Float = 0.75, color: C7Color = .zero, blendMode: BlendMode = .normal) {
        self.start = start
        self.end = end
        self.color = color
        self.blendMode = blendMode
    }
}

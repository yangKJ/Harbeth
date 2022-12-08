//
//  C7Vignette.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

/// 渐晕效果，使边缘的图像淡化
public struct C7Vignette: C7FilterProtocol, ComputeFiltering {
    
    /// The normalized distance from the center where the vignette effect starts, with a default of 0.3
    public var start: Float = 0.3
    /// The normalized distance from the center where the vignette effect ends, with a default of 0.75
    public var end: Float = 0.75
    public var center: C7Point2D = C7Point2D.center
    /// Keep the color scheme
    public var color: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Vignette")
    }
    
    public var factors: [Float] {
        return [center.x, center.y, start, end]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = Vector3.init(color: color).to_factor()
        computeEncoder.setBytes(&factor, length: Vector3.size, index: index + 1)
    }
    
    public init(start: Float = 0.3, end: Float = 0.75, color: C7Color = .zero) {
        self.start = start
        self.end = end
        self.color = color
    }
}

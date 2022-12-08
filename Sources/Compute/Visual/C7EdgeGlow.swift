//
//  C7EdgeGlow.swift
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

import Foundation

public struct C7EdgeGlow: C7FilterProtocol, ComputeFiltering {
    
    /// The adjusted time, from 0.0 to 1.0, with a default of 0.5
    public var time: Float = 0.5
    /// 边缘跨度，比`spacing`大即为边缘，form 0.0 to 1.0
    public var spacing: Float = 0.5
    public var lineColor: C7Color = C7Color.green
    
    public var modifier: Modifier {
        return .compute(kernel: "C7EdgeGlow")
    }
    
    public var factors: [Float] {
        return [time, spacing]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = Vector4.init(color: lineColor).to_factor()
        computeEncoder.setBytes(&factor, length: Vector4.size, index: index + 1)
    }
    
    public init(time: Float = 0.5, spacing: Float = 0.5, lineColor: C7Color = .green) {
        self.time = time
        self.spacing = spacing
        self.lineColor = lineColor
    }
}

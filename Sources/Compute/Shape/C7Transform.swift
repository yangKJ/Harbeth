//
//  C7Transform.swift
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

import Foundation
import simd

public struct C7Transform: C7FilterProtocol, ComputeFiltering {
    
    public var transform: CGAffineTransform
    public var anchorPoint: C7Point2D = C7Point2D.zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7AffineTransform")
    }
    
    public var factors: [Float] {
        return anchorPoint.toXY()
    }
    
    public func resize(input size: C7Size) -> C7Size {
        return mode.transform(transform, size: size)
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = matrix_float3x2(columns: (
            simd_float2(x: Float(transform.a ), y: Float(transform.b )),
            simd_float2(x: Float(transform.c ), y: Float(transform.d )),
            simd_float2(x: Float(transform.tx), y: Float(transform.ty))
        ))
        computeEncoder.setBytes(&factor, length: MemoryLayout<matrix_float3x2>.size, index: index + 1)
    }
    
    private var mode: ShapeMode = .fitSize
    
    public init(mode: ShapeMode = .fitSize, transform: CGAffineTransform) {
        self.transform = transform
        self.mode = mode
    }
}

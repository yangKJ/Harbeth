//
//  C7Transform.swift
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

import Foundation
import simd

public struct C7Transform: C7FilterProtocol {
    
    public var transform: CGAffineTransform
    public var anchorPoint: C7Point2D = C7Point2DZero
    /// True to change image size to fit rotated image, false to keep image size
    public var fitSize: Bool = true
    
    public var modifier: Modifier {
        return .compute(kernel: "C7AffineTransform")
    }
    
    public var factors: [Float] {
        return [anchorPoint.x, anchorPoint.y]
    }
    
    public func outputSize(input size: C7Size) -> C7Size {
        if fitSize {
            let newSize = CGRect(x: 0, y: 0, width: size.width, height: size.height).applying(transform)
            return (width: Int(newSize.width), height: Int(newSize.height))
        }
        return size
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        let computeEncoder = encoder as! MTLComputeCommandEncoder
        var factor = matrix_float3x2(columns: (
            simd_float2(x: Float(transform.a ), y: Float(transform.b )),
            simd_float2(x: Float(transform.c ), y: Float(transform.d )),
            simd_float2(x: Float(transform.tx), y: Float(transform.ty))
        ))
        computeEncoder.setBytes(&factor, length: MemoryLayout<matrix_float3x2>.size, index: index + 1)
    }
    
    public init(transform: CGAffineTransform) {
        self.transform = transform
    }
}

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
    public var anchorPoint: C7Point2D = C7Point2D.zero
    public var samplingMode: SpatialSamplingMode = .adaptive
    public var edgeMode: SpatialEdgeMode = .transparent

    public var modifier: ModifierEnum {
        return .compute(kernel: "C7AffineTransform")
    }

    public var factors: [Float] {
        return anchorPoint.toXY() + [Float(samplingMode.rawValue), Float(edgeMode.rawValue)]
    }

    public func resize(input size: C7Size) -> C7Size {
        return mode.transform(transform, size: size)
    }

    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = matrix_float3x2(columns: (
            simd_float2(x: Float(transform.a), y: Float(transform.b)),
            simd_float2(x: Float(transform.c), y: Float(transform.d)),
            simd_float2(x: Float(transform.tx), y: Float(transform.ty))
        ))
        computeEncoder.setBytes(&factor, length: MemoryLayout<matrix_float3x2>.size, index: index)
    }

    private var mode: Placement = .fit

    public init(mode: Placement = .fit,
                transform: CGAffineTransform,
                samplingMode: SpatialSamplingMode = .adaptive,
                edgeMode: SpatialEdgeMode = .transparent) {
        self.transform = transform
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
        self.mode = mode
    }
}

//
//  C7ColorMatrix4x4.swift
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

import Foundation

/// 每个通道颜色偏移量，在`-255 ~ 255`区间内，配合颜色`Matrix4x4`矩阵使用
/// Each channel color offset, from 0 to 255.
public typealias C7ColorOffset = (red: Int, green: Int, blue: Int, alpha: Int)

public struct C7ColorMatrix4x4: C7FilterProtocol {
    
    /// Color offset for each channel, from -255 to 255.
    public var offset: C7ColorOffset = C7ColorOffset(0, 0, 0, 0)
    /// The degree to which the new transformed color replaces the original color for each pixel, default 1
    public var intensity: Float = 1.0
    private let matrix: Matrix4x4
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorMatrix4x4")
    }
    
    public var factors: [Float] {
        return [intensity, Float(offset.red), Float(offset.green), Float(offset.blue), Float(offset.alpha)]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        let computeEncoder = encoder as! MTLComputeCommandEncoder
        var factor = matrix.to_matrix_float4x4()
        computeEncoder.setBytes(&factor, length: Matrix4x4.size, index: index + 1)
    }
    
    public init(matrix: Matrix4x4) {
        self.matrix = matrix
    }
}

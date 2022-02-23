//
//  Matrix4x4.swift
//  Harbeth
//
//  Created by Condy on 2022/2/23.
//

import Foundation
import simd

extension Matrix4x4 {
    
    public static let size = MemoryLayout<matrix_float4x4>.size
    
    public func to_matrix_float4x4() -> matrix_float4x4 {
        return matrix_float4x4(rows: [
            SIMD4<Float>(values[0], values[4], values[8],  values[12]),
            SIMD4<Float>(values[1], values[5], values[9],  values[13]),
            SIMD4<Float>(values[2], values[6], values[10], values[14]),
            SIMD4<Float>(values[3], values[7], values[11], values[15]),
        ])
    }
}

/// 常见4x4颜色矩阵
/// Common 4x4 color matrix
extension Matrix4x4 {
    
    public static let identity = Matrix4x4(values: [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    ])
    
    /// 棕褐色，老照片
    public static let sepia = Matrix4x4(values: [
        0.3588, 0.7044, 0.1368, 0.0,
        0.2990, 0.5870, 0.1140, 0.0,
        0.2392, 0.4696, 0.0912, 0.0,
        0.0,    0.0,    0.0,    1.0,
    ])
}

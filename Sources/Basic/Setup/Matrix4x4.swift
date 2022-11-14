//
//  Matrix4x4.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import simd

public struct Matrix4x4: Matrix {
    
    public typealias MatrixType = matrix_float4x4
    
    public var values: [Float]
    
    public init(values: [Float]) {
        if values.count != 16 {
            C7FailedErrorInDebug("There must be 16 values for 4x4 Matrix.")
        }
        self.values = values
    }
    
    /// The 4x4 matrix is obtained by CATransform3D
    public init(transform3D: CATransform3D) {
        let values: [Float] = [
            Float(transform3D.m11), Float(transform3D.m12), Float(transform3D.m13), Float(transform3D.m14),
            Float(transform3D.m21), Float(transform3D.m22), Float(transform3D.m23), Float(transform3D.m24),
            Float(transform3D.m31), Float(transform3D.m32), Float(transform3D.m33), Float(transform3D.m34),
            Float(transform3D.m41), Float(transform3D.m42), Float(transform3D.m43), Float(transform3D.m44),
        ]
        self.init(values: values)
    }
    
    public init(transform: CGAffineTransform) {
        self.init(transform3D: CATransform3DMakeAffineTransform(transform))
    }
    
    public func to_factor() -> matrix_float4x4 {
        return matrix_float4x4(rows: [
            SIMD4<Float>(values[0], values[4], values[8],  values[12]),
            SIMD4<Float>(values[1], values[5], values[9],  values[13]),
            SIMD4<Float>(values[2], values[6], values[10], values[14]),
            SIMD4<Float>(values[3], values[7], values[11], values[15]),
        ])
    }
}

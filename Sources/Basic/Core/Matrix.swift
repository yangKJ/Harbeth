//
//  Matrix.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation
import QuartzCore
import CoreGraphics
import simd

open class Matrix {
    public let values: [Float]
    
    init(values: [Float]) {
        self.values = values
    }
}

public class Matrix3x3: Matrix {
    public override init(values: [Float]) {
        if values.count != 9 {
            C7FailedErrorInDebug("There must be nine values for 3x3 Matrix.")
        }
        super.init(values: values)
    }
}

public class Matrix4x4: Matrix {
    
    public override init(values: [Float]) {
        if values.count != 16 {
            C7FailedErrorInDebug("There must be 16 values for 4x4 Matrix.")
        }
        super.init(values: values)
    }
    
    /// The 4x4 matrix is obtained by CATransform3D
    public convenience init(transform3D: CATransform3D) {
        let values: [Float] = [
            Float(transform3D.m11), Float(transform3D.m12), Float(transform3D.m13), Float(transform3D.m14),
            Float(transform3D.m21), Float(transform3D.m22), Float(transform3D.m23), Float(transform3D.m24),
            Float(transform3D.m31), Float(transform3D.m32), Float(transform3D.m33), Float(transform3D.m34),
            Float(transform3D.m41), Float(transform3D.m42), Float(transform3D.m43), Float(transform3D.m44),
        ]
        self.init(values: values)
    }
    
    public convenience init(transform: CGAffineTransform) {
        self.init(transform3D: CATransform3DMakeAffineTransform(transform))
    }
}

// MARK: - Transform
extension Matrix3x3 {
    
    public static let size = MemoryLayout<matrix_float3x3>.size
    
    public func to_matrix_float3x3() -> matrix_float3x3 {
        return matrix_float3x3([
            SIMD3<Float>(values[0], values[1], values[2]),
            SIMD3<Float>(values[3], values[4], values[5]),
            SIMD3<Float>(values[6], values[7], values[8]),
        ])
    }
}

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

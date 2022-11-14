//
//  Matrix3x3.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import simd

public struct Matrix3x3: Matrix {
    
    public typealias MatrixType = matrix_float3x3
    
    public var values: [Float]
    
    public init(values: [Float]) {
        if values.count != 9 {
            C7FailedErrorInDebug("There must be nine values for 3x3 Matrix.")
        }
        self.values = values
    }
    
    public func to_factor() -> matrix_float3x3 {
        return matrix_float3x3([
            SIMD3<Float>(values[0], values[1], values[2]),
            SIMD3<Float>(values[3], values[4], values[5]),
            SIMD3<Float>(values[6], values[7], values[8]),
        ])
    }
}

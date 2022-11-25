//
//  Vector4.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import simd

public struct Vector4: Matrix {
    
    public typealias MatrixType = vector_float4
    
    public var values: [Float]
    
    public init(values: [Float]) {
        if values.count != 4 {
            C7FailedErrorInDebug("There must be nine values for Vector4.")
        }
        self.values = values
    }
    
    public func to_factor() -> vector_float4 {
        vector_float4.init(x: values[0], y: values[1], z: values[2], w: values[3])
    }
}

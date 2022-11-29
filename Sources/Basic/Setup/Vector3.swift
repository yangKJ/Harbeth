//
//  Vector3.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation
import simd

/// 3维向量
public struct Vector3: Matrix {
    
    public typealias MatrixType = vector_float3
    
    public var values: [Float]
    
    public init(values: [Float]) {
        if values.count != 3 {
            C7FailedErrorInDebug("There must be three values for Vector3.")
        }
        self.values = values
    }
    
    public init(color: C7Color) {
        let (red, green, blue, _) = color.mt.toRGBA()
        self.init(values: [red, green, blue])
    }
    
    public func to_factor() -> vector_float3 {
        vector_float3.init(values[0], values[1], values[2])
    }
}

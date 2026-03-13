//
//  Matrix4x5.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// 4 x 5 颜色矩阵
public struct Matrix4x5 {
    
    public let matrix4x4: Matrix4x4
    public let vector4: Vector4
    
    public init(values: [Float]) {
        if values.count != 20 {
            HarbethError.failed("There must be twenty values for 4x5 Matrix.")
        }
        var matrix = [Float]()
        var vector = [Float]()
        for (index, value) in values.enumerated() {
            if (index+7) % 5 == 1 {
                vector.append(value)
            } else {
                matrix.append(value)
            }
        }
        self.matrix4x4 = Matrix4x4(values: matrix)
        self.vector4 = Vector4(values: vector)
    }
    
    private enum CodingKeys: String, CodingKey {
        case matrix4x4
        case vector4
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let matrix4x4Values = try container.decode([Float].self, forKey: .matrix4x4)
        let vector4Values = try container.decode([Float].self, forKey: .vector4)
        self.matrix4x4 = Matrix4x4(values: matrix4x4Values)
        self.vector4 = Vector4(values: vector4Values)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matrix4x4.values, forKey: .matrix4x4)
        try container.encode(vector4.values, forKey: .vector4)
    }
}

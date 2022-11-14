//
//  C7TransformMatrix4x4.swift
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

import Foundation

/// Transform matrix 4x4
public struct C7TransformMatrix4x4: C7FilterProtocol {
    
    private var matrix: Matrix4x4
    
    public var modifier: Modifier {
        return .render(vertex: "vertex_func", fragment: "fragment_func")
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        let computeEncoder = encoder as! MTLComputeCommandEncoder
        var factor = matrix.to_factor()
        computeEncoder.setBytes(&factor, length: Matrix4x4.size, index: index + 1)
    }
    
    public init(matrix: Matrix4x4) {
        self.matrix = matrix
    }
    
    public mutating func updateMatrix4x4(_ matrix: Matrix4x4) {
        self.matrix = matrix
    }
}

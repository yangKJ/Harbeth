//
//  C7ColorMatrix.swift
//  Harbeth
//
//  Created by Condy on 2022/2/21.
//

import Foundation

public struct C7ColorMatrix: C7FilterProtocol {
    
    /// The degree to which the new transformed color replaces the original color for each pixel, default 1
    public var intensity: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorMatrix")
    }
    
    public var factors: [Float] {
        var array = [intensity]
        array += matrix.values
        return array
    }
    
    /// A 4x4 matrix used to transform each color in an image
    private let matrix: Matrix4x4
    
    public init(matrix: Matrix4x4) {
        self.matrix = matrix
    }
}

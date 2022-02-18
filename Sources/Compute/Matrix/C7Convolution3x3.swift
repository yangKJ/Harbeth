//
//  C7Convolution3x3.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation

public enum C7ConvolutionType {
    case `default`
    case gaussian
    case edgedetect
    case emboss
    case morphological
    case sharpen(iterations: Float)
    case custom(Matrix3x3)
}

extension C7ConvolutionType {
    var matrix: Matrix3x3 {
        switch self {
        case .gaussian:
            return Matrix3x3.gaussian
        case .edgedetect:
            return Matrix3x3.edgedetect
        case .emboss:
            return Matrix3x3.emboss
        case .morphological:
            return Matrix3x3.morphological
        case .sharpen(let iterations):
            let cc = Float(8 * iterations + 1)
            let xx = Float(-iterations)
            return Matrix3x3(values: [
                xx, xx, xx,
                xx, cc, xx,
                xx, xx, xx,
            ])
        case .custom(let matrix3x3):
            return matrix3x3
        default:
            return Matrix3x3.`default`
        }
    }
}

/// 3 x 3卷积
public struct C7Convolution3x3: C7FilterProtocol {
    
    var matrix: Matrix3x3
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Convolution3x3")
    }
    
    public var factors: [Float] {
        return matrix.values
    }
    
    public init(matrix: C7ConvolutionType = C7ConvolutionType.default) {
        self.matrix = matrix.matrix
    }
    
    public mutating func updateMatrix(_ matrix: C7ConvolutionType) {
        self.matrix = matrix.matrix
    }
}

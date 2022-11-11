//
//  C7ConvolutionMatrix3x3.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation

/// 3 x 3卷积
public struct C7ConvolutionMatrix3x3: C7FilterProtocol {
    
    public enum ConvolutionType {
        case `default`
        case identity
        case edgedetect
        case embossment
        case embossment45
        case morphological
        case sobel(orientation: Bool)
        case laplance(iterations: Float)
        case sharpen(iterations: Float)
        case custom(Matrix3x3)
    }
    
    /// Convolution pixels, default 1
    public var convolutionPixel: Int = 1
    private var matrix: Matrix3x3
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ConvolutionMatrix3x3")
    }
    
    public var factors: [Float] {
        var array = [Float(convolutionPixel)]
        array += matrix.values
        return array
    }
    
    public init(matrix: Matrix3x3) {
        self.matrix = matrix
    }
    
    public init(convolutionType: ConvolutionType) {
        self.init(matrix: convolutionType.matrix)
    }
    
    public mutating func updateConvolutionType(_ convolutionType: ConvolutionType) {
        self.matrix = convolutionType.matrix
    }
    
    public mutating func updateMatrix3x3(_ matrix: Matrix3x3) {
        self.matrix = matrix
    }
}

extension C7ConvolutionMatrix3x3.ConvolutionType {
    var matrix: Matrix3x3 {
        switch self {
        case .identity:
            return Matrix3x3.identity
        case .edgedetect:
            return Matrix3x3.edgedetect
        case .embossment:
            return Matrix3x3.embossment
        case .embossment45:
            return Matrix3x3.embossment45
        case .morphological:
            return Matrix3x3.morphological
        case .sobel(let orientation):
            return Matrix3x3.sobel(orientation)
        case .laplance(let iterations):
            return Matrix3x3.laplance(iterations)
        case .sharpen(let iterations):
            return Matrix3x3.sharpen(iterations)
        case .custom(let matrix3x3):
            return matrix3x3
        default:
            return Matrix3x3.`default`
        }
    }
}

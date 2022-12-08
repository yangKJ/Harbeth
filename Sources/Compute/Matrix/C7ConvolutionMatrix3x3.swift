//
//  C7ConvolutionMatrix3x3.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation

/// 3 x 3卷积
public struct C7ConvolutionMatrix3x3: C7FilterProtocol, ComputeFiltering {
    
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
        return [Float(convolutionPixel)]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = matrix.to_factor()
        computeEncoder.setBytes(&factor, length: Matrix3x3.size, index: index + 1)
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
            return Matrix3x3.Kernel.identity
        case .edgedetect:
            return Matrix3x3.Kernel.edgedetect
        case .embossment:
            return Matrix3x3.Kernel.embossment
        case .embossment45:
            return Matrix3x3.Kernel.embossment45
        case .morphological:
            return Matrix3x3.Kernel.morphological
        case .sobel(let orientation):
            return Matrix3x3.Kernel.sobel(orientation)
        case .laplance(let iterations):
            return Matrix3x3.Kernel.laplance(iterations)
        case .sharpen(let iterations):
            return Matrix3x3.Kernel.sharpen(iterations)
        case .custom(let matrix3x3):
            return matrix3x3
        default:
            return Matrix3x3.Kernel.`default`
        }
    }
}

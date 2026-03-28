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
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ConvolutionMatrix3x3")
    }
    
    public var factors: [Float] {
        return [intensity, Float(convolutionPixel)]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var factor = matrix.to_factor()
        computeEncoder.setBytes(&factor, length: Matrix3x3.size, index: index)
    }
    
    public init(matrix: Matrix3x3, intensity: Float = 1.0) {
        self.matrix = matrix
        self.intensity = intensity
    }
    
    public init(convolutionType: C7ConvolutionMatrix3x3.ConvolutionType, intensity: Float = 1.0) {
        self.init(matrix: convolutionType.matrix, intensity: intensity)
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
    
    public func updateConvolutionType(_ convolutionType: C7ConvolutionMatrix3x3.ConvolutionType) -> Self {
        var copy = self
        copy.matrix = convolutionType.matrix
        return copy
    }
    
    public func updateMatrix3x3(_ matrix: Matrix3x3) -> Self {
        var copy = self
        copy.matrix = matrix
        return copy
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

//
//  C7FalseColor.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// 使用图像的亮度在两种用户指定的颜色之间进行混合
/// Uses the luminance of the image to mix between two user-specified colors
public struct C7FalseColor: C7FilterProtocol, ComputeFiltering {
    
    /// The first and second colors specify what colors replace the dark and light areas of the image, respectively.
    public var fristColor: C7Color = .zero
    
    public var secondColor: C7Color = .zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7FalseColor")
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var fristFactor = Vector3.init(color: fristColor).to_factor()
        computeEncoder.setBytes(&fristFactor, length: Vector3.size, index: index + 1)
        var secondFactor = Vector3(color: secondColor).to_factor()
        computeEncoder.setBytes(&secondFactor, length: Vector3.size, index: index + 2)
    }
    
    public init(fristColor: C7Color = .zero, secondColor: C7Color = .zero) {
        self.fristColor = fristColor
        self.secondColor = secondColor
    }
}

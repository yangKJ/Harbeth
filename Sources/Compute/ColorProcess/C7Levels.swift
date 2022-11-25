//
//  C7Levels.swift
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

import Foundation

/// 色阶
public struct C7Levels: C7FilterProtocol {
    
    public var minimum: C7Color = C7Color.black
    public var middle:  C7Color = C7Color.white
    public var maximum: C7Color = C7Color.white
    public var minOutput: C7Color = C7Color.black
    public var maxOutput: C7Color = C7Color.white
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LevelsFilter")
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var _minimum = minimum.mt.toC7RGBAColor()
        var _middle = middle.mt.toC7RGBAColor()
        var _maximum = maximum.mt.toC7RGBAColor()
        var _minOutput = minOutput.mt.toC7RGBAColor()
        var _maxOutput = maxOutput.mt.toC7RGBAColor()
        let size = MemoryLayout<RGBAColor>.size
        computeEncoder.setBytes(&_minimum, length: size, index: index + 1)
        computeEncoder.setBytes(&_middle, length: size, index: index + 2)
        computeEncoder.setBytes(&_maximum, length: size, index: index + 3)
        computeEncoder.setBytes(&_minOutput, length: size, index: index + 4)
        computeEncoder.setBytes(&_maxOutput, length: size, index: index + 5)
    }
    
    public init() { }
}

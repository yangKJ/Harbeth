//
//  C7Levels.swift
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

import Foundation

/// 色阶
public struct C7Levels: C7FilterProtocol, ComputeFiltering {
    
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
        var _minimum = Vector3(color: minimum).to_factor()
        var _middle  = Vector3(color: middle).to_factor()
        var _maximum = Vector3(color: maximum).to_factor()
        var _minOutput = Vector3(color: minOutput).to_factor()
        var _maxOutput = Vector3(color: maxOutput).to_factor()
        let size = Vector3.size
        computeEncoder.setBytes(&_minimum, length: size, index: index + 1)
        computeEncoder.setBytes(&_middle, length: size, index: index + 2)
        computeEncoder.setBytes(&_maximum, length: size, index: index + 3)
        computeEncoder.setBytes(&_minOutput, length: size, index: index + 4)
        computeEncoder.setBytes(&_maxOutput, length: size, index: index + 5)
    }
    
    public init() { }
}

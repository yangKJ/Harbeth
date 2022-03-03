//
//  C7Levels.swift
//  Harbeth
//
//  Created by Condy on 2022/2/24.
//

import Foundation
import class UIKit.UIColor

/// 色阶
public struct C7Levels: C7FilterProtocol {
    
    public var minimum: UIColor = UIColor.black
    public var middle:  UIColor = UIColor.white
    public var maximum: UIColor = UIColor.white
    public var minOutput: UIColor = UIColor.black
    public var maxOutput: UIColor = UIColor.white
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LevelsFilter")
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        let computeEncoder = encoder as! MTLComputeCommandEncoder
        var _minimum = minimum.mt.toC7Color()
        var _middle = middle.mt.toC7Color()
        var _maximum = maximum.mt.toC7Color()
        var _minOutput = minOutput.mt.toC7Color()
        var _maxOutput = maxOutput.mt.toC7Color()
        let size = MemoryLayout<C7Color>.size
        computeEncoder.setBytes(&_minimum, length: size, index: index + 1)
        computeEncoder.setBytes(&_middle, length: size, index: index + 2)
        computeEncoder.setBytes(&_maximum, length: size, index: index + 3)
        computeEncoder.setBytes(&_minOutput, length: size, index: index + 4)
        computeEncoder.setBytes(&_maxOutput, length: size, index: index + 5)
    }
    
    public init() { }
}

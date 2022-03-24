//
//  C7FalseColor.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

/// 使用图像的亮度在两种用户指定的颜色之间进行混合
/// Uses the luminance of the image to mix between two user-specified colors
public struct C7FalseColor: C7FilterProtocol {
    
    /// The first and second colors specify what colors replace the dark and light areas of the image, respectively.
    public var fristColor: C7Color = C7EmptyColor {
        didSet {
            fristColor.mt.toRGB(red: &r, green: &g, blue: &b)
        }
    }
    
    public var secondColor: C7Color = C7EmptyColor {
        didSet {
            secondColor.mt.toRGB(red: &r2, green: &g2, blue: &b2)
        }
    }
    
    private var r: Float = 0
    private var g: Float = 0
    private var b: Float = 0.5
    private var r2: Float = 1
    private var g2: Float = 0
    private var b2: Float = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7FalseColor")
    }
    
    public var factors: [Float] {
        return [r, g, b, r2, g2, b2]
    }
    
    public init() { }
}

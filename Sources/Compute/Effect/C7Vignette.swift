//
//  C7Vignette.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation
import class UIKit.UIColor

/// 渐晕效果，使边缘的图像淡化
public struct C7Vignette: C7FilterProtocol {
    
    /// The normalized distance from the center where the vignette effect starts, with a default of 0.3
    public var start: Float = 0.3
    /// The normalized distance from the center where the vignette effect ends, with a default of 0.75
    public var end: Float = 0.75
    public var center: C7Point2D = C7Point2DCenter
    /// Keep the color scheme
    public var color: UIColor = C7EmptyColor {
        didSet {
            color.mt.toRGB(red: &red, green: &green, blue: &blue)
        }
    }
    
    private var red: Float = 1
    private var green: Float = 1
    private var blue: Float = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Vignette")
    }
    
    public var factors: [Float] {
        return [center.x, center.y, red, green, blue, start, end]
    }
    
    public init() { }
}

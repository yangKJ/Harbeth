//
//  C7ChromaKey.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 祛除某种色系，有点类似绿幕抠图，被祛除的像素会变透明
/// Remove a certain color system, a bit like green screen matting, The removed pixels become transparent
public struct C7ChromaKey: C7FilterProtocol {
    
    /// How close a color match needs to exist to the target color to be replaced (default of 0.4)
    public var thresholdSensitivity: Float = 0.4
    /// How smoothly to blend for the color match (default of 0.1)
    public var smoothing: Float = 0.1
    /// Color patches that need to be removed,
    public var color: UIColor {
        didSet {
            if color != UIColor.clear {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                red = Float(r); green = Float(g); blue = Float(b)
            }
        }
    }
    
    private var red: Float = 0
    private var green: Float = 1
    private var blue: Float = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ChromaKey")
    }
    
    public var factors: [Float] {
        return [thresholdSensitivity, smoothing, red, green, blue]
    }
    
    public init() {
        self.color = UIColor.clear
    }
}

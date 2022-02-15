//
//  C7Vignette.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/14.
//

import Foundation

public struct C7Vignette: C7FilterProtocol {
    
    /// The normalized distance from the center where the vignette effect starts, with a default of 0.3
    public var start: Float = 0.3
    /// The normalized distance from the center where the vignette effect ends, with a default of 0.75
    public var end: Float = 0.75
    /// 2D textures, normalized texture coordinates are used, from 0.0 to 1.0 in both x and y directions
    public var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// Keep the color scheme
    public var color: UIColor {
        didSet {
            if color != UIColor.clear {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                red = Float(r); green = Float(g); blue = Float(b)
            }
        }
    }
    
    private var red: Float = 1
    private var green: Float = 1
    private var blue: Float = 1
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Vignette")
    }
    
    public var factors: [Float] {
        return [Float(center.x), Float(center.y), red, green, blue, start, end]
    }
    
    public init() {
        self.color = UIColor.clear
    }
}

//
//  C7EdgeGlow.swift
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

import Foundation
import class UIKit.UIColor

public struct C7EdgeGlow: C7FilterProtocol {
    
    /// The adjusted time, from 0.0 to 1.0, with a default of 0.5
    public var time: Float = 0.5
    /// 边缘跨度，比`spacing`大即为边缘，form 0.0 to 1.0
    public var spacing: Float = 0.5
    public var lineColor: UIColor = UIColor.green {
        didSet {
            lineColor.mt.toRGBA(red: &r, green: &g, blue: &b, alpha: &a)
        }
    }
    
    private var r: Float = 0.0
    private var g: Float = 1.0
    private var b: Float = 0.0
    private var a: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7EdgeGlow")
    }
    
    public var factors: [Float] {
        return [time, spacing, r, g, b, a]
    }
    
    public init() { }
}

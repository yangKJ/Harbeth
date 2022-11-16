//
//  C7Crosshatch.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// 绘制阴影线
public struct C7Crosshatch: C7FilterProtocol {
    
    /// The fractional width of the image to use as the spacing for the crosshatch, default of 0.03
    public var crosshatchSpacing: Float = 0.03
    /// A relative width for the crosshatch lines, default of 0.003
    public var lineWidth: Float = 0.003
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Crosshatch")
    }
    
    public var factors: [Float] {
        return [crosshatchSpacing, lineWidth]
    }
    
    public init(crosshatchSpacing: Float = 0.03, lineWidth: Float = 0.003) {
        self.crosshatchSpacing = crosshatchSpacing
        self.lineWidth = lineWidth
    }
}

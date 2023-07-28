//
//  C7ColorRGBA.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7ColorRGBA: C7FilterProtocol {
    
    /// Specifies the intensity of the operation.
    @ZeroOneRange public var intensity: Float = IntensityRange.value
    
    /// Modify the value of color single channel, `1` keeps the source channel color, `>1` adds red pigment, `<1` reduces red pigment
    @ZeroOneRange public var red: Float = 1
    @ZeroOneRange public var green: Float = 1
    @ZeroOneRange public var blue: Float = 1
    @ZeroOneRange public var alpha: Float = 1
    /// Transparent colors are not processed, Will directly modify the overall color scheme
    public var color: C7Color = .white {
        didSet {
            (self.red, self.green, self.blue, self.alpha) = color.mt.toRGBA()
        }
    }
    
    public var modifier: Modifier {
        return .compute(kernel: "C7ColorRGBA")
    }
    
    public var factors: [Float] {
        return [red, green, blue, alpha, intensity]
    }
    
    public init(color: C7Color = .white) {
        self.color = color
        (self.red, self.green, self.blue, self.alpha) = color.mt.toRGBA()
    }
}

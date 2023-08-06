//
//  CIBrightness.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIBrightness: C7FilterProtocol, CoreImageProtocol {
    
    /// The adjusted brightness, from -1.0 to 1.0, with a default of 0.0 being the original picture.
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    @Clamping(range.min...range.max) public var brightness: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIColorControls")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        return ciImage
    }
    
    public init(brightness: Float = range.value) {
        self.brightness = brightness
    }
}

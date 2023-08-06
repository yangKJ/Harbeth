//
//  CISaturation.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CISaturation: C7FilterProtocol, CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    @Clamping(range.min...range.max) public var saturation: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIColorControls")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(saturation + 1, forKey: kCIInputSaturationKey)
        return ciImage
    }
    
    public init(saturation: Float = range.value) {
        self.saturation = saturation
    }
}

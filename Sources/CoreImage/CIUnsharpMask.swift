//
//  CIUnsharpMask.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIUnsharpMask: C7FilterProtocol, CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 0.3, value: 0.0)
    
    @Clamping(range.min...range.max) public var intensity: Float = range.value
    
    @ZeroOneRange public var radius: Float = 0.0
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIUnsharpMask")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        let radius = ciImage.extent.c7.radius(radius, max: Self.range.max)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        return ciImage
    }
    
    public init(intensity: Float = range.value, radius: Float = 0) {
        self.radius = radius
        self.intensity = intensity
    }
}

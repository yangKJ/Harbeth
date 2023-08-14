//
//  CIVignette.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIVignette: C7FilterProtocol, CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 2, value: 0.0)
    
    @Clamping(range.min...range.max) public var vignette: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIVignette")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        let radius = ciImage.extent.c7.radius(vignette, max: Self.range.max)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(vignette, forKey: kCIInputIntensityKey)
        return ciImage
    }
    
    public init(vignette: Float = range.value) {
        self.vignette = vignette
    }
}

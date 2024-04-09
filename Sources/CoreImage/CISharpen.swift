//
//  CISharpen.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CISharpen: CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 1.0, value: 0.0)
    
    @Clamping(range.min...range.max) public var sharpness: Float = range.value
    
    public var radius: Float = 0.0
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CISharpenLuminance")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        let radius = ciImage.extent.c7.radius(radius, max: Self.range.max)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(sharpness, forKey: kCIInputSharpnessKey)
        return ciImage
    }
    
    public init(sharpness: Float = range.value, radius: Float = 0.0) {
        self.radius = radius
        self.sharpness = sharpness
    }
}

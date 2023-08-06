//
//  CIGaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIGaussianBlur: C7FilterProtocol, CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10.0)
    
    @Clamping(range.min...range.max) public var radius: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIGaussianBlur")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        let radius = RadiusCalculator.radius(radius, max: Self.range.max, rect: ciImage.extent)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        // Return a new infinite image by replicating the edge pixels of a rectangle.
        // Cut the blurred area next to it.
        return ciImage.clamped(to: ciImage.extent)
    }
    
    public init(radius: Float = range.value) {
        self.radius = radius
    }
}

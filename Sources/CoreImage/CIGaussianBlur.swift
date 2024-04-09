//
//  CIGaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIGaussianBlur: CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10.0)
    
    @Clamping(range.min...range.max) public var radius: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIGaussianBlur")
    }
    
    public var croppedOutputImage: Bool {
        return true
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        let radius = ciImage.extent.c7.radius(radius, max: Self.range.max)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        // Return a new infinite image by replicating the edge pixels of a rectangle.
        // Cut the blurred area next to it.
        return ciImage.clamped(to: ciImage.extent)
    }
    
    public init(radius: Float = range.value) {
        self.radius = radius
    }
}

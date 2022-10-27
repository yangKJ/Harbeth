//
//  CIGaussianBlur.swift
//  Harbeth
//
//  Created by Condy on 2022/9/23.
//

import Foundation
import CoreImage

/// 高斯模糊
/// https://cifilter.io/CIGaussianBlur/
public struct CIGaussianBlur: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0, max: 100, value: 10)
    
    /// The radius determines how many pixels are used to create the blur.
    public var radius: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIFilterName: "CIGaussianBlur")
    }
    
    public func coreImageApply(filter: CIFilter?, input ciImage: CIImage) -> CIImage {
        filter?.setValue(radius, forKey: "inputRadius")
        return ciImage.cropped(to: ciImage.extent)
    }
    
    public init() { }
}

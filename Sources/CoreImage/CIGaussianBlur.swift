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
    
    /// The radius determines how many pixels are used to create the blur.
    public var radius: Float = 10
    
    public var modifier: Modifier {
        return .coreimage(CIFilterName: "CIGaussianBlur")
    }
    
    public func coreImageSetupCIFilter(_ filter: CIFilter?, input cgimage: CGImage) {
        filter?.setValue(radius, forKey: "inputRadius")
    }
    
    public init() { }
}
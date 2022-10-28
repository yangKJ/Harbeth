//
//  CIHighlight.swift
//  Harbeth
//
//  Created by 77。 on 2022/7/13.
//

import Foundation
import CoreImage

/// 高光
/// https://cifilter.io/CIHighlightShadowAdjust/
public struct CIHighlight: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    public var value: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIFilterName: "CIHighlightShadowAdjust")
    }
    
    public func coreImageApply(filter: CIFilter?, input ciImage: CIImage) -> CIImage {
        filter?.setValue(1 - value, forKey: "inputHighlightAmount")
        return ciImage.cropped(to: ciImage.extent)
    }
    
    public init() { }
}

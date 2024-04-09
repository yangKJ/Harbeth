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
public struct CIHighlight: CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    @ZeroOneRange public var highlight: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIHighlightShadowAdjust")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(1 - highlight, forKey: "inputHighlightAmount")
        return ciImage
    }
    
    public init(highlight: Float = range.value) {
        self.highlight = highlight
    }
}

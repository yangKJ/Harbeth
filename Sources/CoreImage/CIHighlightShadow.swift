//
//  CIHighlightShadow.swift
//  Harbeth
//
//  Created by 77。 on 2022/7/13.
//

import Foundation
import CoreImage

/// 高光阴影
public struct CIHighlightShadow: C7FilterProtocol {
    
    /// 范围 0 - 1
    public var value: Float = 0
    
    public var modifier: Modifier {
        return .coreimage(CIFilterName: "CIHighlightShadowAdjust")
    }
    
    public func coreImageSetupCIFilter(_ filter: CIFilter?, input cgimage: CGImage) {
        filter?.setValue(1 - value, forKey: "inputHighlightAmount")
    }
    
    public init() { }
}

//
//  CIWhitePoint.swift
//  Harbeth
//
//  Created by Condy on 2022/11/24.
//

import Foundation
import CoreImage

/// Adjusts the reference white point for an image and maps all colors in the source using the new reference.
/// https://cifilter.io/CIWhitePointAdjust/
public struct CIWhitePoint: C7FilterProtocol, CoreImageFiltering {
    
    /// A color to use as the white point.
    public var color: C7Color = .white {
        didSet {
            self.ciColor = CIColor(color: color)
        }
    }
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIWhitePointAdjust")
    }
    
    public func coreImageApply(filter: CIFilter?, input ciImage: CIImage) -> CIImage {
        filter?.setValue(ciColor, forKey: "inputColor")
        return ciImage.cropped(to: ciImage.extent)
    }
    
    private var ciColor: CIColor!
    
    public init(color: C7Color = .white) {
        self.color = color
        self.ciColor = CIColor(color: color)
    }
}

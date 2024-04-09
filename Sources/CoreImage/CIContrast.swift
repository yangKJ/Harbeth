//
//  CIContrast.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIContrast: CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.0, max: 1.0, value: 0.0)
    
    @Clamping(range.min...range.max) public var contrast: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIColorControls")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(contrast + 1, forKey: kCIInputContrastKey)
        return ciImage
    }
    
    public init(contrast: Float = range.value) {
        self.contrast = contrast
    }
}

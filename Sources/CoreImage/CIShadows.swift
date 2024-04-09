//
//  CIShadows.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIShadows: CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1, max: 1, value: 0.0)
    
    @Clamping(range.min...range.max) public var shadows: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIHighlightShadowAdjust")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(shadows, forKey: "inputShadowAmount")
        return ciImage
    }
    
    public init(shadows: Float = range.value) {
        self.shadows = shadows
    }
}

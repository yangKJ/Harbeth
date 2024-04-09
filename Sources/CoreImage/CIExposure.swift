//
//  CIExposure.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIExposure: CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -1.8, max: 1.8, value: 0.0)
    
    @Clamping(range.min...range.max) public var exposure: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIExposureAdjust")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(exposure, forKey: kCIInputEVKey)
        return ciImage
    }
    
    public init(exposure: Float = range.value) {
        self.exposure = exposure
    }
}

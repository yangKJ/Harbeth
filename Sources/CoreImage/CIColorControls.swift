//
//  CIColorControls.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

/// 调整亮度、饱和度和对比度
public struct CIColorControls: CoreImageProtocol {
    
    /// The adjusted brightness, from -1.0 to 1.0, with a default of 0.0.
    @Clamping(CIBrightness.range.min...CIBrightness.range.max) public var brightness: Float = CIBrightness.range.value
    
    /// The adjusted saturation, from -1.0 to 1.0, with a default of 0.0.
    @Clamping(CISaturation.range.min...CISaturation.range.max) public var saturation: Float = CISaturation.range.value
    
    /// The adjusted contrast, from -0.18 to 0.18, with a default of 0.0.
    @Clamping(CIContrast.range.min...CIContrast.range.max) public var contrast: Float = CIContrast.range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIColorControls")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(saturation + 1, forKey: kCIInputSaturationKey)
        filter.setValue(contrast + 1, forKey: kCIInputContrastKey)
        return ciImage
    }
    
    public init() { }
}

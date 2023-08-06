//
//  CIFade.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CIFade: C7FilterProtocol, CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    @Clamping(range.min...range.max) public var intensity: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CISourceOverCompositing")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        let mFilter = CIFilter(name: "CIConstantColorGenerator", parameters: [
            kCIInputColorKey : CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(intensity))
        ])
        guard let foreground = mFilter?.outputImage else {
            throw CustomError.outputCIImage("CIConstantColorGenerator")
        }
        filter.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
        return foreground
    }
    
    public init(intensity: Float = range.value) {
        self.intensity = intensity
    }
}

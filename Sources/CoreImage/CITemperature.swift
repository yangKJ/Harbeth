//
//  CITemperature.swift
//  Harbeth
//
//  Created by Condy on 2023/8/6.
//

import Foundation
import CoreImage

public struct CITemperature: CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: -3000, max: 3000, value: 0.0)
    
    @Clamping(range.min...range.max) public var temperature: Float = range.value
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CITemperatureAndTint")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(CIVector.init(x: CGFloat(temperature) + 6500, y: 0), forKey: "inputNeutral")
        filter.setValue(CIVector.init(x: 6500, y: 0), forKey: "inputTargetNeutral")
        return ciImage
    }
    
    public init(temperature: Float = range.value) {
        self.temperature = temperature
    }
}

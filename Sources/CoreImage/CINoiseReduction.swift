//
//  CINoiseReduction.swift
//  Harbeth
//
//  Created by Condy on 2024/3/25.
//

import Foundation
import CoreImage

public struct CINoiseReduction: CoreImageProtocol {
    
    public var noiseLevel: Float = 0.02
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CINoiseReduction")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(noiseLevel, forKey: "inputNoiseLevel")
        return ciImage
    }
    
    public init(noiseLevel: Float = 0.02) {
        self.noiseLevel = noiseLevel
    }
}

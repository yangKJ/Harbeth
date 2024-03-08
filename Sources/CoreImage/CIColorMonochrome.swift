//
//  CIColorMonochrome.swift
//  Harbeth
//
//  Created by Condy on 2024/3/3.
//

import Foundation
import CoreImage

/// 单色滤镜
public struct CIColorMonochrome: C7FilterProtocol, CoreImageProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    @Clamping(range.min...range.max) public var intensity: Float = range.value
    
    /// A color to use as the white point.
    public var color: C7Color = .white {
        didSet {
            self.ciColor = CIColor.init(color: color)
        }
    }
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CIColorMonochrome")
    }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        filter.setValue(ciColor, forKey: kCIInputColorKey)
        return ciImage
    }
    
    private var ciColor: CIColor!
    
    public init(color: C7Color = .white) {
        self.color = color
        self.ciColor = CIColor.init(color: color)
    }
}

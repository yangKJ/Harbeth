//
//  C7ColorConvert.swift
//  Harbeth
//
//  Created by Condy on 2021/8/8.
//

import Foundation

/// 颜色通道`RGB`位置转换
public struct C7ColorConvert: C7FilterProtocol {
    
    public enum ColorType: String, CaseIterable {
        case invert = "C7ColorInvert"
        case gray = "C7Color2Gray"
        case bgra = "C7Color2BGRA"
        case brga = "C7Color2BRGA"
        case gbra = "C7Color2GBRA"
        case grba = "C7Color2GRBA"
        case rbga = "C7Color2RBGA"
        case y = "C7Color2Y"
    }
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    private let type: ColorType
    
    public var modifier: Modifier {
        return .compute(kernel: type.rawValue)
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public init(with type: ColorType) {
        self.type = type
    }
}

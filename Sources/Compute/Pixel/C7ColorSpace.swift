//
//  C7ColorSpace.swift
//  Harbeth
//
//  Created by Condy on 2022/12/20.
//

import Foundation

/// 色彩空间转换
public struct C7ColorSpace: C7FilterProtocol {
    
    public enum SwapType: String, CaseIterable {
        case rgb_to_yiq = "C7ColorSpaceRGB2YIQ"
        case yiq_to_rgb = "C7ColorSpaceYIQ2RGB"
        case rgb_to_yuv = "C7ColorSpaceRGB2YUV"
        case yuv_to_rgb = "C7ColorSpaceYUV2RGB"
    }
    
    private let type: SwapType
    
    public var modifier: Modifier {
        return .compute(kernel: type.rawValue)
    }
    
    public init(with type: SwapType) {
        self.type = type
    }
}

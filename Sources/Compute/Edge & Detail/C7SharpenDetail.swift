//
//  C7SharpenDetail.swift
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

import Foundation

/// 锐化、清晰度、细节增强综合滤镜
/// Sharpen, Clarity, and Detail Enhancement combined filter
public struct C7SharpenDetail: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.0)
    
    /// 锐化强度，0.0-1.0，值越大锐化效果越明显
    /// Sharpen intensity, 0.0-1.0, higher values increase sharpness
    @ZeroOneRange public var sharpen: Float = range.value
    
    /// 清晰度，0.0-1.0，值越大中间调反差越强
    /// Clarity, 0.0-1.0, higher values increase mid-tone contrast
    @ZeroOneRange public var clarity: Float = range.value
    
    /// 细节增强，0.0-1.0，值越大细节越明显
    /// Detail enhancement, 0.0-1.0, higher values enhance details
    @ZeroOneRange public var detail: Float = range.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7SharpenDetail")
    }
    
    public var factors: [Float] {
        return [sharpen, clarity, detail]
    }
    
    public init(sharpen: Float = 0,  clarity: Float = 0, detail: Float = 0) {
        self.sharpen = sharpen
        self.clarity = clarity
        self.detail = detail
    }
}

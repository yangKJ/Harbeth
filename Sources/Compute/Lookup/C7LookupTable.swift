//
//  C7LookupTable.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/9.
//

import Foundation
import MetalKit

/// LUT映射滤镜
/// See: https://juejin.cn/post/7169096223100829709
public struct C7LookupTable: C7FilterProtocol {
    
    /// Opacity of lookup filter ranges from 0.0 to 1.0, with 1.0 as the normal setting.
    @ZeroOneRange public var intensity: Float = R.iRange.value
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LookupTable")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: C7InputTextures {
        return lookupTexture == nil ? [] : [lookupTexture!]
    }
    
    private let lookupImage: C7Image?
    private let lookupTexture: MTLTexture?
    
    public init(image: C7Image?) {
        self.lookupImage = image
        self.lookupTexture = image?.cgImage?.c7.toTexture()
    }
    
    public init(name: String) {
        self.init(image: R.image(name))
    }
    
    public init(lookupTexture: MTLTexture) {
        self.lookupImage = nil
        self.lookupTexture = lookupTexture
    }
}

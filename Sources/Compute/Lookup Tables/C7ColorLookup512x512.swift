//
//  C7ColorLookup512x512.swift
//  Harbeth
//
//  Created by Condy on 2026/2/11.
//

import Foundation
import MetalKit

/// 512x512 颜色查找表滤镜，用于高质量的颜色调整
/// 512x512 color search table filter for high-quality color
public struct C7ColorLookup512x512: C7FilterProtocol {
    
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorLookup512x512")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: C7InputTextures {
        return lookupTexture == nil ? [] : [lookupTexture!]
    }
    
    private let lookupTexture: MTLTexture?
    
    public init(lookupImage: C7Image) {
        self.lookupTexture = lookupImage.cgImage?.c7.toTexture()
    }
    
    public init(lookupTexture: MTLTexture) {
        self.lookupTexture = lookupTexture
    }
}

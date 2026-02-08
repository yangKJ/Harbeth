//
//  C7BlendWithMask.swift
//  Harbeth
//
//  Created by Condy on 2026/2/8.
//

import Foundation

public struct C7BlendWithMask: C7FilterProtocol {
    
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7BlendWithMask")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: C7InputTextures {
        return [foregroundTexture, maskTexture]
    }
    
    private let foregroundTexture: MTLTexture
    private let maskTexture: MTLTexture
    
    public init(foregroundTexture: MTLTexture, maskTexture: MTLTexture) {
        self.foregroundTexture = foregroundTexture
        self.maskTexture = maskTexture
    }
    
    public mutating func updateIntensity(_ value: Float) {
        self.intensity = value
    }
}

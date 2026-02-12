//
//  C7Blend.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

public struct C7Blend: C7FilterProtocol {
    
    public enum BlendType {
        case add
        case alpha
        case colorBurn
        case colorDodge
        case darken
        case darkerColor
        case difference
        case dissolve
        case divide
        case exclusion
        case hardLight
        case hardMix
        case hue
        case lighten
        case lighterColor
        case linearBurn
        case linearLight
        case luminosity
        case mask
        case multiply
        case normal
        case overlay
        case pinLight
        case saturation
        case screen
        case softLight
        case sourceOver
        case subtract
        case vividLight
        case color
    }
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    public var modifier: ModifierEnum {
        return .compute(kernel: blendType.kernel)
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: C7InputTextures {
        return blendTexture == nil ? [] : [blendTexture!]
    }
    
    private let blendTexture: MTLTexture?
    private var blendType: BlendType
    
    public init(with type: BlendType, image: C7Image) {
        let overTexture = image.cgImage?.c7.toTexture()
        self.init(with: type, blendTexture: overTexture)
    }
    
    public init(with type: BlendType, blendTexture: MTLTexture?) {
        self.blendType = type
        self.blendTexture = blendTexture
    }
    
    public mutating func updateBlend(_ type: BlendType) {
        self.blendType = type
    }
}

extension C7Blend.BlendType: Hashable, Identifiable {
    
    public var id: String {
        kernel
    }
    
    public var kernel: String {
        switch self {
        case .add:
            return "C7BlendColorAdd"
        case .alpha:
            return "C7BlendColorAlpha"
        case .colorBurn:
            return "C7BlendColorBurn"
        case .colorDodge:
            return "C7BlendColorDodge"
        case .darken:
            return "C7BlendDarken"
        case .darkerColor:
            return "C7BlendDarkerColor"
        case .difference:
            return "C7BlendDifference"
        case .dissolve:
            return "C7BlendDissolve"
        case .divide:
            return "C7BlendDivide"
        case .exclusion:
            return "C7BlendExclusion"
        case .hardLight:
            return "C7BlendHardLight"
        case .hardMix:
            return "C7BlendHardMix"
        case .hue:
            return "C7BlendHue"
        case .lighten:
            return "C7BlendLighten"
        case .lighterColor:
            return "C7BlendLighterColor"
        case .linearBurn:
            return "C7BlendLinearBurn"
        case .linearLight:
            return "C7BlendLinearLight"
        case .luminosity:
            return "C7BlendLuminosity"
        case .mask:
            return "C7BlendMask"
        case .multiply:
            return "C7BlendMultiply"
        case .normal:
            return "C7BlendNormal"
        case .overlay:
            return "C7BlendOverlay"
        case .pinLight:
            return "C7BlendPinLight"
        case .saturation:
            return "C7BlendSaturation"
        case .screen:
            return "C7BlendScreen"
        case .softLight:
            return "C7BlendSoftLight"
        case .sourceOver:
            return "C7BlendSourceOver"
        case .subtract:
            return "C7BlendSubtract"
        case .vividLight:
            return "C7BlendVividLight"
        case .color:
            return "C7BlendColor"
        }
    }
}

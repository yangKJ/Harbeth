//
//  C7Blend.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

public struct C7Blend: C7FilterProtocol {
    
    public enum BlendType {
        case chromaKey(threshold: Float = 0.4, smoothing: Float = 0.1, color: C7Color = .white)
        case add
        case alpha
        case colorBurn
        case colorDodge
        case darken
        case difference
        case dissolve
        case divide
        case exclusion
        case hardLight
        case hue
        case lighten
        case linearBurn
        case luminosity
        case mask
        case multiply
        case normal
        case overlay
        case screen
        case softLight
        case sourceOver
        case subtract
    }
    
    /// Specifies the intensity of the operation.
    @ZeroOneRange public var intensity: Float = R.iRange.value
    
    public var modifier: Modifier {
        return .compute(kernel: blendType.kernel)
    }
    
    public var factors: [Float] {
        switch blendType {
        case .chromaKey(let threshold, let smoothing, let color):
            let (red, green, blue, _) = color.c7.toRGBA()
            return [threshold, smoothing, red, green, blue, intensity]
        default:
            return [intensity]
        }
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
            return "C7AddBlend"
        case .alpha:
            return "C7AlphaBlend"
        case .colorBurn:
            return "C7ColorBurnBlend"
        case .colorDodge:
            return "C7ColorDodgeBlend"
        case .chromaKey:
            return "C7ChromaKeyBlend"
        case .darken:
            return "C7DarkenBlend"
        case .difference:
            return "C7DifferenceBlend"
        case .dissolve:
            return "C7DissolveBlend"
        case .divide:
            return "C7DivideBlend"
        case .exclusion:
            return "C7ExclusionBlend"
        case .hardLight:
            return "C7HardLightBlend"
        case .hue:
            return "C7HueBlend"
        case .lighten:
            return "C7LightenBlend"
        case .linearBurn:
            return "C7LinearBurnBlend"
        case .luminosity:
            return "C7LuminosityBlend"
        case .mask:
            return "C7MaskBlend"
        case .multiply:
            return "C7MultiplyBlend"
        case .normal:
            return "C7NormalBlend"
        case .overlay:
            return "C7OverlayBlend"
        case .screen:
            return "C7ScreenBlend"
        case .softLight:
            return "C7SoftLightBlend"
        case .sourceOver:
            return "C7SourceOverBlend"
        case .subtract:
            return "C7SubtractBlend"
        }
    }
}

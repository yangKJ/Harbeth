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
        case add
        case alpha(mixturePercent: Float)
        case colorBurn
        case colorDodge
        case darken
        case difference
        case dissolve
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
        case chromaKey(threshold: Float = 0.4, smoothing: Float = 0.1, color: C7Color = C7Color.green)
    }
    
    public let blendImage: C7Image
    public let blendTexture: MTLTexture?
    public private(set) var blendType: BlendType
    
    public var modifier: Modifier {
        return .compute(kernel: blendType.kernel)
    }
    
    public var factors: [Float] {
        switch blendType {
        case .alpha(let mixturePercent):
            return [mixturePercent]
        case .chromaKey(let threshold, let smoothing, let color):
            let (red, green, blue, _) = color.mt.toRGBA()
            return [threshold, smoothing, red, green, blue]
        default:
            return []
        }
    }
    
    public var otherInputTextures: C7InputTextures {
        return blendTexture == nil ? [] : [blendTexture!]
    }
    
    public init(with type: BlendType, image: C7Image) {
        self.blendType = type
        self.blendImage = image
        self.blendTexture = image.cgImage?.mt.newTexture()
    }
    
    public mutating func updateBlend(_ type: BlendType) {
        self.blendType = type
    }
}

extension C7Blend.BlendType {
    var kernel: String {
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

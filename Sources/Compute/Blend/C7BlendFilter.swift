//
//  C7BlendFilter.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation

public enum BlendFilterType {
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

extension BlendFilterType {
    var kernel: String {
        switch self {
        case .add: return "C7AddBlend"
        case .alpha: return "C7AlphaBlend"
        case .colorBurn: return "C7ColorBurnBlend"
        case .colorDodge: return "C7ColorDodgeBlend"
        case .chromaKey: return "C7ChromaKeyBlend"
        case .darken: return "C7DarkenBlend"
        case .difference: return "C7DifferenceBlend"
        case .dissolve: return "C7DissolveBlend"
        case .exclusion: return "C7ExclusionBlend"
        case .hardLight: return "C7HardLightBlend"
        case .hue: return "C7HueBlend"
        case .lighten: return "C7LightenBlend"
        case .linearBurn: return "C7LinearBurnBlend"
        case .luminosity: return "C7LuminosityBlend"
        case .mask: return "C7MaskBlend"
        case .multiply: return "C7MultiplyBlend"
        case .normal: return "C7NormalBlend"
        case .overlay: return "C7OverlayBlend"
        case .screen: return "C7ScreenBlend"
        case .softLight: return "C7SoftLightBlend"
        case .sourceOver: return "C7SourceOverBlend"
        case .subtract: return "C7SubtractBlend"
        }
    }
}

public struct C7BlendFilter: C7FilterProtocol {
    
    public private(set) var blendImage: C7Image?
    public private(set) var blendType: BlendFilterType
    
    public var modifier: Modifier {
        return .compute(kernel: blendType.kernel)
    }
    
    public var factors: [Float] {
        switch blendType {
        case .alpha(let mixturePercent):
            return [mixturePercent]
        case .chromaKey(let threshold, let smoothing, let color):
            var red: Float = 0, green: Float = 0, blue: Float = 0
            color.mt.toRGB(red: &red, green: &green, blue: &blue)
            return [threshold, smoothing, red, green, blue]
        default:
            return []
        }
    }
    
    public var otherInputTextures: C7InputTextures {
        if let texture = blendImage?.cgImage?.mt.newTexture() {
            return [texture]
        }
        return []
    }
    
    public init(with type: BlendFilterType, image: C7Image) {
        self.blendType = type
        self.blendImage = image
    }
    
    public mutating func updateBlend(_ type: BlendFilterType) {
        self.blendType = type
    }
}

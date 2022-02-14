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
}

extension BlendFilterType {
    var kernel: String {
        switch self {
        case .add: return "C7AddBlend"
        case .alpha: return "C7AlphaBlend"
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
        default:
            return []
        }
    }
    
    public var otherInputTextures: MTQInputTextures {
        if let texture = blendImage?.mt.toTexture() {
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

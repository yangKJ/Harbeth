//
//  C7LookupSplit.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation
import MetalKit

public struct C7LookupSplit: C7FilterProtocol {
    
    public enum Orientation {
        case top, left, center
        case topLeft, bottomLeft
    }

    public static let progressRange: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    public let lookupTexture1: MTLTexture?
    public let lookupTexture2: MTLTexture?
    
    @ZeroOneRange public var intensity: Float = 1.0
    /// Split range, from 0.0 to 1.0, with a default of 0.0
    @ZeroOneRange public var progress: Float = progressRange.value
    public var orientation: Orientation = .center
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LookupSplit")
    }
    
    public var factors: [Float] {
        return [intensity, progress, orientation.factorValue]
    }
    
    public var otherInputTextures: C7InputTextures {
        if let texture1 = lookupTexture1, let texture2 = lookupTexture2 {
            return [texture1, texture2]
        }
        return []
    }
    
    public init(_ lookupImage: C7Image, lookupImage2: C7Image) {
        self.lookupTexture1 = lookupImage.cgImage?.mt.toTexture()
        self.lookupTexture2 = lookupImage2.cgImage?.mt.toTexture()
    }
    
    public init(_ lookupTexture: MTLTexture, lookupTexture2: MTLTexture) {
        self.lookupTexture1 = lookupTexture
        self.lookupTexture2 = lookupTexture2
    }
}

extension C7LookupSplit.Orientation {
    var factorValue: Float {
        switch self {
        case .top:
            return 0.0
        case .left:
            return 1.0
        case .center:
            return 2.0
        case .topLeft:
            return 3.0
        case .bottomLeft:
            return 4.0
        }
    }
}

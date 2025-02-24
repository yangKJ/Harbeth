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
    
    /// Split progress range.
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    
    /// Split range, from 0.0 to 1.0, with a default of 0.0
    @ZeroOneRange public var progress: Float = range.value
    
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
    
    private let lookupTexture1: MTLTexture?
    private let lookupTexture2: MTLTexture?
    
    public init(_ lookupImage: C7Image, lookupImage2: C7Image) {
        self.lookupTexture1 = lookupImage.cgImage?.c7.toTexture()
        self.lookupTexture2 = lookupImage2.cgImage?.c7.toTexture()
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

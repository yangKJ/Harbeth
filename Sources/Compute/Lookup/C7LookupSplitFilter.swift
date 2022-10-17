//
//  C7LookupSplitFilter.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation
import MetalKit

public enum C7SplitOrientation {
    case top, left, center
    case topLeft, bottomLeft
}

extension C7SplitOrientation {
    var factorValue: Float {
        switch self {
        case .top: return 0.0
        case .left: return 1.0
        case .center: return 2.0
        case .topLeft: return 3.0
        case .bottomLeft: return 4.0
        }
    }
}

public struct C7LookupSplitFilter: C7FilterProtocol {
    
    public let lookupTexture1: MTLTexture?
    public let lookupTexture2: MTLTexture?
    
    public var orientation: C7SplitOrientation = .center
    public var intensity: Float = 1.0
    /// Split range, from 0.0 to 1.0, with a default of 0.0
    public var progress: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LookupSplitFilter")
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
        self.lookupTexture1 = lookupImage.cgImage?.mt.newTexture()
        self.lookupTexture2 = lookupImage2.cgImage?.mt.newTexture()
    }
}

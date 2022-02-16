//
//  C7LookupSplitFilter.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

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
    
    public private(set) var lookupImage1: C7Image?
    public private(set) var lookupImage2: C7Image?
    
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
        if let texture1 = lookupImage1?.mt.toTexture(),
           let texture2 = lookupImage2?.mt.toTexture() {
            return [texture1, texture2]
        }
        return []
    }
    
    public init(_ lookupImage: C7Image, lookupImage2: C7Image) {
        self.lookupImage1 = lookupImage
        self.lookupImage2 = lookupImage2
    }
}

//
//  C7LookupSplitFilter.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation

public struct C7LookupSplitFilter: C7FilterProtocol {
    
    public private(set) var lookupImage1: C7Image?
    public private(set) var lookupImage2: C7Image?
    
    public var intensity: Float = 1.0
    public var progress: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LookupSplitFilter")
    }
    
    public var factors: [Float] {
        return [intensity, progress]
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

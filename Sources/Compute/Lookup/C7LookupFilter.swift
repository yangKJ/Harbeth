//
//  C7LookupFilter.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/9.
//

import Foundation

public struct C7LookupFilter: C7FilterProtocol {
    
    public private(set) var minIntensity: Float = 0.0
    public private(set) var maxIntensity: Float = 100//MAXFLOAT
    public private(set) var lookupImage: C7Image?
    public var intensity: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LookupFilter")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: MTQInputTextures {
        if let texture = lookupImage?.mt.toTexture() {
            return [texture]
        }
        return []
    }
    
    public init(image: C7Image) {
        lookupImage = image
    }
    
    public init(name: String) {
        lookupImage = C7Image(named: name)
    }
}

//
//  C7LookupFilter.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/9.
//

import Foundation
import MetalKit

/// LUT映射滤镜
public struct C7LookupFilter: C7FilterProtocol {
    
    public let lookupImage: C7Image?
    public let lookupTexture: MTLTexture?
    public var intensity: Float = 1.0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LookupFilter")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherInputTextures: C7InputTextures {
        return lookupTexture == nil ? [] : [lookupTexture!]
    }
    
    public init(image: C7Image?) {
        self.lookupImage = image
        self.lookupTexture = image?.cgImage?.mt.newTexture()
    }
    
    public init(name: String) {
        self.init(image: R.image(name))
    }
}

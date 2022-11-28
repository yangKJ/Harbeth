//
//  C7LookupTable.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/9.
//

import Foundation
import MetalKit

/// LUT映射滤镜
public struct C7LookupTable: C7FilterProtocol {
    
    public static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 1.0)
    
    /// Opacity of lookup filter ranges from 0.0 to 1.0, with 1.0 as the normal setting.
    @ZeroOneRange public var intensity: Float = range.value
    
    public let lookupImage: C7Image?
    public let lookupTexture: MTLTexture?
    
    public var modifier: Modifier {
        return .compute(kernel: "C7LookupTable")
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

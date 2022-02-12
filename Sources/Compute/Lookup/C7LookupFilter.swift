//
//  C7LookupFilter.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/9.
//

import Foundation
import class UIKit.UIImage

public struct C7LookupFilter: C7FilterProtocol {
    
    public private(set) var minIntensity: Float = 0.0
    public private(set) var maxIntensity: Float = 100//MAXFLOAT
    public private(set) var lookupImage: MTQImage?
    public var intensity: Float = 0.0
    
    public var modifier: Modifier {
        return .compute(kernel: "LookupFilter")
    }
    
    public var factors: [Float] {
        return [intensity]
    }
    
    public var otherFiterImage: MTQImage? {
        return lookupImage
    }
    
    public init(image: MTQImage) {
        lookupImage = image
    }
    
    public init(name: String) {
        lookupImage = MTQImage(named: name)
    }
}

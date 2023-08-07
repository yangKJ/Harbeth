//
//  C7DepthLuminance.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7DepthLuminance: C7FilterProtocol {
    
    public var offect: Float = 0
    public var range: Float = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7DepthLuminance")
    }
    
    public var factors: [Float] {
        return [offect, range]
    }
    
    public init(offect: Float = 0, range: Float = 0) {
        self.offect = offect
        self.range = range
    }
}

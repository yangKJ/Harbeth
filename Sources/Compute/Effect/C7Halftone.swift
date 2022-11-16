//
//  C7Halftone.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Halftone: C7FilterProtocol {
    
    /// How large the halftone dots are, as a fraction of the width of the image, default of 0.01
    public var fractionalWidth: Float = 0.01
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Halftone")
    }
    
    public var factors: [Float] {
        return [fractionalWidth]
    }
    
    public init(fractionalWidth: Float = 0.01) {
        self.fractionalWidth = fractionalWidth
    }
}

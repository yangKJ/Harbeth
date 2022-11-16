//
//  C7PolkaDot.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7PolkaDot: C7FilterProtocol {
    
    /// How large the dots are, as a fraction of the width and height of the image, default of 0.05
    public var fractionalWidth: Float = 0.05
    /// What fraction of each grid space is taken up by a dot, default of 0.9
    public var dotScaling: Float = 0.9
    
    public var modifier: Modifier {
        return .compute(kernel: "C7PolkaDot")
    }
    
    public var factors: [Float] {
        return [fractionalWidth, dotScaling]
    }
    
    public init(fractionalWidth: Float = 0.05, dotScaling: Float = 0.9) {
        self.fractionalWidth = fractionalWidth
        self.dotScaling = dotScaling
    }
}

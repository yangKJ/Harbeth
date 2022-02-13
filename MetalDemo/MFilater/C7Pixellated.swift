//
//  C7Pixellated.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import ATMetalBand

public struct C7Pixellated: C7FilterProtocol {
    
    public var pixelWidth: Float = 0.05
    
    public var modifier: Modifier {
        return .compute(kernel: "Pixellated")
    }
    
    public var factors: [Float] {
        return [pixelWidth]
    }
    
    public init(pixelWidth: Float = 0.05) {
        self.pixelWidth = pixelWidth
    }
}

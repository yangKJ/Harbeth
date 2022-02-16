//
//  C7Pixellated.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/13.
//

import Foundation

public struct C7Pixellated: C7FilterProtocol {
    
    /// Adjust the pixel color block size,  from 0.0 to 1.0, with a default of 0.05
    public var pixelWidth: Float = 0.05
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Pixellated")
    }
    
    public var factors: [Float] {
        return [pixelWidth]
    }
    
    public init() { }
}

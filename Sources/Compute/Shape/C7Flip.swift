//
//  C7Flip.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Flip: C7FilterProtocol {
    
    /// Whether to flip horizontally or not
    public var horizontal: Bool = false
    /// Whether to flip vertically or not
    public var vertical: Bool = false
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Flip")
    }
    
    public var factors: [Float] {
        return [horizontal ? 1.0 : 0.0, vertical ? 1.0 : 0.0]
    }
    
    public init(horizontal: Bool = false, vertical: Bool = false) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
}

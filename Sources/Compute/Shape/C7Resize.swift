//
//  C7Resize.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// Pull and compress the picture, the picture will be distorted
public struct C7Resize: C7FilterProtocol {
    
    public var width: Float
    public var height: Float
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Resize")
    }
    
    public func resize(input size: C7Size) -> C7Size {
        return ShapeMode.fitSize.resize(width: width, height: height, size: size)
    }
    
    public init(size: CGSize) {
        self.width = Float(size.width)
        self.height = Float(size.height)
    }
    
    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }
}

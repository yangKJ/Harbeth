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
    
    private var size: CGSize = .zero {
        didSet {
            if size.width > 0 {
                self.width = Float(size.width)
            }
            if size.height > 0 {
                self.height = Float(size.height)
            }
        }
    }
    
    public init(size: CGSize) {
        self.size = size
        self.width = Float(size.width)
        self.height = Float(size.height)
    }
    
    public init(width: Float, height: Float) {
        self.size = CGSize(width: CGFloat(width), height: CGFloat(height))
        self.width = width
        self.height = height
    }
}

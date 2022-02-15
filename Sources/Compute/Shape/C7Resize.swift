//
//  C7Resize.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Resize: C7FilterProtocol {
    
    public var width: Int = 0
    public var height: Int = 0
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Resize")
    }
    
    public func outputSize(input size: MTQSize) -> MTQSize {
        let w: Int = width > 0 ? width : size.width
        let h: Int = height > 0 ? height : size.height
        return (width: w, height: h)
    }
    
    public init() { }
}

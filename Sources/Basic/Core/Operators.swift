//
//  Operators.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit

precedencegroup AppendPrecedence {
    associativity: left
    higherThan: LogicalConjunctionPrecedence
}

infix operator ->> : AppendPrecedence

@discardableResult
public func ->> (left: MTLTexture, right: C7FilterProtocol) -> MTLTexture {
    if let destTexture = try? Processed.IO(inTexture: left, filter: right) {
        return destTexture
    }
    return left
}

@discardableResult
public func ->> (left: C7Image, right: C7FilterProtocol) -> C7Image {
    if let image: C7Image = try? left.make(filter: right) {
        return image
    }
    return left
}

@discardableResult
public func ->> (left: C7Collector, right: C7FilterProtocol) -> C7Collector {
    left.filters.append(right)
    return left
}

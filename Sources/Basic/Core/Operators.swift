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

//@discardableResult
public func ->> (left: C7FilterTexture, right: C7FilterProtocol) -> C7FilterTexture {
    var temp = left
    temp.updateInputTexture(temp.destTexture)
    _ = try? temp.make(filter: right) as C7FilterTexture
    return temp
}

@discardableResult
public func ->> (left: MTLTexture, right: C7FilterProtocol) -> MTLTexture {
    if let destTexture = try? Processed.generateOutTexture(inTexture: left, filter: right) {
        return destTexture
    }
    return left
}

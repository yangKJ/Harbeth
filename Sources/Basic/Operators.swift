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
public func ->> (left: C7FilterProtocol, right: C7FilterProtocol) -> C7FilterProtocol {
    // TODO:
    return right
}

//
//  Operators.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import CoreVideo
import MetalKit

precedencegroup AppendPrecedence {
    associativity: left
    higherThan: LogicalConjunctionPrecedence
}

infix operator ->> : AppendPrecedence

@discardableResult
public func ->> (left: MTLTexture, right: C7FilterProtocol) -> MTLTexture {
    let dest = BoxxIO.init(element: left, filters: [right])
    return (try? dest.output()) ?? left
}

@discardableResult
public func ->> (left: C7Image, right: C7FilterProtocol) -> C7Image {
    let dest = BoxxIO.init(element: left, filters: [right])
    return (try? dest.output()) ?? left
}

@discardableResult
public func ->> (left: CGImage, right: C7FilterProtocol) -> CGImage {
    let dest = BoxxIO.init(element: left, filters: [right])
    return (try? dest.output()) ?? left
}

@discardableResult
public func ->> (left: CIImage, right: C7FilterProtocol) -> CIImage {
    let dest = BoxxIO.init(element: left, filters: [right])
    return (try? dest.output()) ?? left
}

@discardableResult
public func ->> (left: CMSampleBuffer, right: C7FilterProtocol) -> CMSampleBuffer {
    let dest = BoxxIO.init(element: left, filters: [right])
    return (try? dest.output()) ?? left
}

@discardableResult
public func ->> (left: CVPixelBuffer, right: C7FilterProtocol) -> CVPixelBuffer {
    let dest = BoxxIO.init(element: left, filters: [right])
    return (try? dest.output()) ?? left
}

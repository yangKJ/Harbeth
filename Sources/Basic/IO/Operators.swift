//
//  Operators.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import CoreImage
import CoreVideo
import MetalKit

precedencegroup AppendPrecedence {
    associativity: left
    higherThan: LogicalConjunctionPrecedence
}

infix operator ->> : AppendPrecedence
infix operator -->>> : AppendPrecedence

// MARK: - single operator

@discardableResult
public func ->> (left: MTLTexture, right: C7FilterProtocol) -> MTLTexture {
    (try? HarbethIO(element: left, filter: right).output()) ?? left
}

@discardableResult
public func ->> (left: C7Image, right: C7FilterProtocol) -> C7Image {
    (try? HarbethIO(element: left, filter: right).output()) ?? left
}

@discardableResult
public func ->> (left: CGImage, right: C7FilterProtocol) -> CGImage {
    (try? HarbethIO(element: left, filter: right).output()) ?? left
}

@discardableResult
public func ->> (left: CIImage, right: C7FilterProtocol) -> CIImage {
    (try? HarbethIO(element: left, filter: right).output()) ?? left
}

@discardableResult
public func ->> (left: CMSampleBuffer, right: C7FilterProtocol) -> CMSampleBuffer {
    (try? HarbethIO(element: left, filter: right).output()) ?? left
}

@discardableResult
public func ->> (left: CVPixelBuffer, right: C7FilterProtocol) -> CVPixelBuffer {
    (try? HarbethIO(element: left, filter: right).output()) ?? left
}


// MARK: - array operator

@discardableResult
public func -->>> (left: MTLTexture, right: [C7FilterProtocol]) -> MTLTexture {
    (try? HarbethIO(element: left, filters: right).output()) ?? left
}

@discardableResult
public func -->>> (left: C7Image, right: [C7FilterProtocol]) -> C7Image {
    (try? HarbethIO(element: left, filters: right).output()) ?? left
}

@discardableResult
public func -->>> (left: CGImage, right: [C7FilterProtocol]) -> CGImage {
    (try? HarbethIO(element: left, filters: right).output()) ?? left
}

@discardableResult
public func -->>> (left: CIImage, right: [C7FilterProtocol]) -> CIImage {
    (try? HarbethIO(element: left, filters: right).output()) ?? left
}

@discardableResult
public func -->>> (left: CMSampleBuffer, right: [C7FilterProtocol]) -> CMSampleBuffer {
    (try? HarbethIO(element: left, filters: right).output()) ?? left
}

@discardableResult
public func -->>> (left: CVPixelBuffer, right: [C7FilterProtocol]) -> CVPixelBuffer {
    (try? HarbethIO(element: left, filters: right).output()) ?? left
}

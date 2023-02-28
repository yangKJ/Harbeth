//
//  Operators.swift
//  Harbeth
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
infix operator -->>> : AppendPrecedence

// MARK: - single operator

@discardableResult @inlinable
public func ->> (left: MTLTexture, right: C7FilterProtocol) -> MTLTexture {
    (try? BoxxIO.init(element: left, filters: [right]).output()) ?? left
}

@discardableResult @inlinable
public func ->> (left: C7Image, right: C7FilterProtocol) -> C7Image {
    (try? BoxxIO.init(element: left, filters: [right]).output()) ?? left
}

@discardableResult @inlinable
public func ->> (left: CGImage, right: C7FilterProtocol) -> CGImage {
    (try? BoxxIO.init(element: left, filters: [right]).output()) ?? left
}

@discardableResult @inlinable
public func ->> (left: CIImage, right: C7FilterProtocol) -> CIImage {
    (try? BoxxIO.init(element: left, filters: [right]).output()) ?? left
}

@discardableResult @inlinable
public func ->> (left: CMSampleBuffer, right: C7FilterProtocol) -> CMSampleBuffer {
    (try? BoxxIO.init(element: left, filters: [right]).output()) ?? left
}

@discardableResult @inlinable
public func ->> (left: CVPixelBuffer, right: C7FilterProtocol) -> CVPixelBuffer {
    (try? BoxxIO.init(element: left, filters: [right]).output()) ?? left
}


// MARK: - array operator

@discardableResult @inlinable
public func -->>> (left: MTLTexture, right: [C7FilterProtocol]) -> MTLTexture {
    (try? BoxxIO.init(element: left, filters: right).output()) ?? left
}

@discardableResult @inlinable
public func -->>> (left: C7Image, right: [C7FilterProtocol]) -> C7Image {
    (try? BoxxIO.init(element: left, filters: right).output()) ?? left
}

@discardableResult @inlinable
public func -->>> (left: CGImage, right: [C7FilterProtocol]) -> CGImage {
    (try? BoxxIO.init(element: left, filters: right).output()) ?? left
}

@discardableResult @inlinable
public func -->>> (left: CIImage, right: [C7FilterProtocol]) -> CIImage {
    (try? BoxxIO.init(element: left, filters: right).output()) ?? left
}

@discardableResult @inlinable
public func -->>> (left: CMSampleBuffer, right: [C7FilterProtocol]) -> CMSampleBuffer {
    (try? BoxxIO.init(element: left, filters: right).output()) ?? left
}

@discardableResult @inlinable
public func -->>> (left: CVPixelBuffer, right: [C7FilterProtocol]) -> CVPixelBuffer {
    (try? BoxxIO.init(element: left, filters: right).output()) ?? left
}

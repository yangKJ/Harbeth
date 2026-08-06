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
func ->> (left: MTLTexture, right: C7FilterProtocol) -> MTLTexture {
    HarbethIO(element: left, filter: right).filtered()
}

@discardableResult
func ->> (left: C7Image, right: C7FilterProtocol) -> C7Image {
    HarbethIO(element: left, filter: right).filtered()
}

@discardableResult
func ->> (left: CGImage, right: C7FilterProtocol) -> CGImage {
    HarbethIO(element: left, filter: right).filtered()
}

@discardableResult
func ->> (left: CIImage, right: C7FilterProtocol) -> CIImage {
    HarbethIO(element: left, filter: right).filtered()
}

@discardableResult
func ->> (left: CMSampleBuffer, right: C7FilterProtocol) -> CMSampleBuffer {
    HarbethIO(element: left, filter: right).filtered()
}

@discardableResult
func ->> (left: CVPixelBuffer, right: C7FilterProtocol) -> CVPixelBuffer {
    HarbethIO(element: left, filter: right).filtered()
}


// MARK: - array operator

@discardableResult
func -->>> (left: MTLTexture, right: [C7FilterProtocol]) -> MTLTexture {
    HarbethIO(element: left, filters: right).filtered()
}

@discardableResult
func -->>> (left: C7Image, right: [C7FilterProtocol]) -> C7Image {
    HarbethIO(element: left, filters: right).filtered()
}

@discardableResult
func -->>> (left: CGImage, right: [C7FilterProtocol]) -> CGImage {
    HarbethIO(element: left, filters: right).filtered()
}

@discardableResult
func -->>> (left: CIImage, right: [C7FilterProtocol]) -> CIImage {
    HarbethIO(element: left, filters: right).filtered()
}

@discardableResult
func -->>> (left: CMSampleBuffer, right: [C7FilterProtocol]) -> CMSampleBuffer {
    HarbethIO(element: left, filters: right).filtered()
}

@discardableResult
func -->>> (left: CVPixelBuffer, right: [C7FilterProtocol]) -> CVPixelBuffer {
    HarbethIO(element: left, filters: right).filtered()
}

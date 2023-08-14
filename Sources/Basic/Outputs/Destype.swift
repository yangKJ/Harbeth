//
//  Destype.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//

import Foundation

public protocol Destype {
    
    associatedtype Element
    
    var element: Element { get }
    var filters: [C7FilterProtocol] { get }
    
    init(element: Element, filter: C7FilterProtocol)
    
    init(element: Element, filters: [C7FilterProtocol])
    
    /// Add filters to sources synchronously.
    /// - Returns: Added filter source.
    func output() throws -> Element
    
    /// Asynchronous quickly add filters to sources.
    /// - Parameter success: Successful callback of adding filters to the sources asynchronously.
    func transmitOutput(success: @escaping (Element) -> Void)
    
    /// Asynchronous quickly add filters to sources.
    /// - Parameters:
    ///   - success: Successful callback of adding filters to the sources asynchronously.
    ///   - failed: An error occurred during the conversion process, the error is `CustomError`.
    func transmitOutput(success: @escaping (Element) -> Void, failed: @escaping (CustomError) -> Void)
}

extension Destype {
    public func transmitOutput(success: @escaping (Element) -> Void) {
        transmitOutput(success: success, failed: { _ in })
    }
}

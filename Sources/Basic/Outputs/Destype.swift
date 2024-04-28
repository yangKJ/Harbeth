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
    
    func filtered() -> Element
    
    /// Add filters to sources synchronously.
    /// - Returns: Added filter source.
    func output() throws -> Element
    
    /// Asynchronous quickly add filters to sources.
    /// - Parameter complete: The conversion is complete of adding filters to the sources asynchronously.
    func transmitOutput(complete: @escaping (Result<Element, HarbethError>) -> Void)
}

extension Destype {
    
    public init(element: Element, filter: C7FilterProtocol) {
        self.init(element: element, filters: [filter])
    }
    
    public func filtered() -> Element {
        do {
            return try self.output()
        } catch {
            return element
        }
    }
    
    public func transmitOutput(success: @escaping (Element) -> Void, failed: ((HarbethError) -> Void)? = nil) {
        transmitOutput { res in
            switch res {
            case .success(let result):
                success(result)
            case .failure(let error):
                failed?(error)
            }
        }
    }
}

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
    /// - Parameter complete: The conversion is complete of adding filters to the sources asynchronously.
    func transmitOutput(complete: @escaping (Result<Element, HarbethError>) -> Void)
    
    /// Asynchronous convert to texture and add filters.
    /// - Parameters:
    ///   - texture: Input metal texture.
    ///   - complete: The conversion is complete.
    func filtering(texture: MTLTexture, complete: @escaping (Result<MTLTexture, HarbethError>) -> Void)
}

extension Destype {
    /// Asynchronous quickly add filters to sources.
    /// - Parameters:
    ///   - success: Successful callback of adding filters to the sources asynchronously.
    ///   - failed: An error occurred during the conversion process, the error is `HarbethError`.
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
